<?php

/*
 * Copyright (C) 2026 os-netmap contributors
 * All rights reserved.
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * GET /api/netmap/map/topology
 *
 * Builds a D3-ready { nodes, links } graph from:
 *   - config.xml            : interfaces + physical device names
 *   - /var/db/hostwatch/hosts.db : discovered hosts via v_hosts view
 *
 * Implementation notes:
 *   - Uses SQLite3 class (not PDO) — pdo_sqlite absent in OPNsense 26.x.
 *   - Opens DB SQLITE3_OPEN_READONLY.
 *   - hostwatch stores physical device names (igc1, vlan0.160) in
 *     interface_name; resolved to config tag via <if> field in config.xml.
 *   - All output sanitised with htmlspecialchars.
 *   - Cache written atomically (tmp + rename), TTL 60 s.
 */

namespace OPNsense\Netmap\Api;

use OPNsense\Base\ApiControllerBase;
use OPNsense\Core\Config;
use OPNsense\Core\Backend;

class MapController extends ApiControllerBase
{
    private const CACHE_FILE = '/tmp/netmap_topology.json';
    private const CACHE_TTL  = 60;
    private const HOST_LIMIT = 2000;
    private const DB_PATH    = '/var/db/hostwatch/hosts.db';

    // -------------------------------------------------------------------------

    public function topologyAction(): array
    {
        if ($this->isCacheFresh()) {
            $cached = @file_get_contents(self::CACHE_FILE);
            if ($cached !== false) {
                $decoded = json_decode($cached, true);
                if (is_array($decoded)) {
                    return $decoded;
                }
            }
        }

        $topology = $this->buildTopology();
        $this->writeCache($topology);
        return $topology;
    }

    // -------------------------------------------------------------------------

    private function buildTopology(): array
    {
        $nodes = [];
        $links = [];

        $nodes['router'] = [
            'id'     => 'router',
            'type'   => 'router',
            'label'  => 'OPNsense',
            'ip'     => null,
            'mac'    => null,
            'vendor' => 'Deciso B.V.',
        ];

        $hostnames  = $this->getHostnames();
        $interfaces = $this->getConfiguredInterfaces();
        foreach ($interfaces as $tag => $intf) {
            $nodeId         = 'net_' . $tag;
            $nodes[$nodeId] = [
                'id'     => $nodeId,
                'type'   => 'subnet',
                'label'  => $intf['descr'],
                'cidr'   => $intf['cidr'],
                'ifname' => $tag,
            ];
            $links[] = ['source' => 'router', 'target' => $nodeId];
        }

        foreach ($this->getHostwatchHosts() as $host) {
            $ip     = $host['ip_address']     ?? '';
            $ifname = $host['interface_name'] ?? '';

            if (!filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
                continue;
            }

            $nodeId   = 'host_' . preg_replace('/[^a-zA-Z0-9]/', '_', $ip);
            $subnetId = $this->resolveSubnet($ifname, $interfaces) ?? 'router';
            $hostname = $hostnames[$ip] ?? '';

            $nodes[$nodeId] = [
                'id'         => $nodeId,
                'type'       => 'host',
                'label'      => $this->sanitise($hostname ?: $ip),
                'ip'         => $this->sanitise($ip),
                'mac'        => $this->sanitise($host['ether_address']     ?? ''),
                'vendor'     => $this->sanitise($host['organization_name'] ?? ''),
                'hostname'   => $this->sanitise($hostname),
                'first_seen' => $this->sanitise($host['first_seen']        ?? ''),
                'last_seen'  => $this->sanitise($host['last_seen']         ?? ''),
                'ifname'     => $this->sanitise($ifname),
            ];
            $links[] = ['source' => $subnetId, 'target' => $nodeId];
        }

        $vpnData = $this->getVpnNodes();
        $vpnLinks = $vpnData['__vpn_links__'] ?? [];
        unset($vpnData['__vpn_links__']);
        foreach ($vpnData as $nodeId => $node) {
            $nodes[$nodeId] = $node;
        }
        foreach ($vpnLinks as $vpnLink) {
            $links[] = $vpnLink;
        }

        return ['nodes' => array_values($nodes), 'links' => $links];
    }

    // -------------------------------------------------------------------------

    /**
     * VPN topology: OpenVPN servers + connected clients, WireGuard servers + peers.
     * Returns flat array keyed by node ID (merged directly into $nodes).
     * Links are appended to $links via a separate key '__links__'.
     */
    private function getVpnNodes(): array
    {
        $nodes = [];
        $links = [];

        // ---- OpenVPN ---------------------------------------------------------
        $config = Config::getInstance()->object();
        foreach ((array)($config->openvpn->{'openvpn-server'} ?? []) as $server) {
            $vpnId = (int)($server->vpnid ?? 0);
            if (!$vpnId) {
                continue;
            }
            $descr  = $this->sanitise(trim((string)($server->description ?? 'OpenVPN ' . $vpnId)));
            $tunnel = $this->sanitise(trim((string)($server->tunnel_network ?? '')));

            $nodeId        = 'vpn_ovpn_' . $vpnId;
            $nodes[$nodeId] = [
                'id'    => $nodeId,
                'type'  => 'vpn',
                'label' => $descr ?: 'OpenVPN ' . $vpnId,
                'cidr'  => $tunnel,
                'proto' => 'OpenVPN',
            ];
            $links[] = ['source' => 'router', 'target' => $nodeId];

            foreach ($this->readOpenVpnClients($vpnId) as $ip => $cn) {
                $cId        = 'vpnc_' . preg_replace('/[^a-zA-Z0-9]/', '_', $ip);
                $nodes[$cId] = [
                    'id'       => $cId,
                    'type'     => 'vpn_client',
                    'label'    => $this->sanitise($cn ?: $ip),
                    'ip'       => $this->sanitise($ip),
                    'hostname' => $this->sanitise($cn),
                    'proto'    => 'OpenVPN',
                ];
                $links[] = ['source' => $nodeId, 'target' => $cId];
            }
        }

        // ---- WireGuard -------------------------------------------------------
        try {
            $wg = $config->OPNsense->wireguard ?? null;
            if ($wg) {
                // Build peer-uuid → peer-info lookup
                $peerNames = [];
                foreach ($wg->client->clients->client ?? [] as $client) {
                    $uuid              = (string)($client['uuid'] ?? '');
                    $peerNames[$uuid] = [
                        'name'   => trim((string)($client->name           ?? '')),
                        'tunnel' => trim((string)($client->tunneladdress  ?? '')),
                    ];
                }

                foreach ($wg->server->servers->server ?? [] as $srv) {
                    if (trim((string)($srv->enabled ?? '0')) !== '1') {
                        continue;
                    }
                    $name   = $this->sanitise(trim((string)($srv->name          ?? 'WireGuard')));
                    $tunnel = $this->sanitise(trim((string)($srv->tunneladdress ?? '')));
                    $uuid   = (string)($srv['uuid'] ?? '');
                    $nodeId = 'vpn_wg_' . preg_replace('/[^a-zA-Z0-9]/', '_', $uuid ?: $name);

                    $nodes[$nodeId] = [
                        'id'    => $nodeId,
                        'type'  => 'vpn',
                        'label' => $name ?: 'WireGuard',
                        'cidr'  => $tunnel,
                        'proto' => 'WireGuard',
                    ];
                    $links[] = ['source' => 'router', 'target' => $nodeId];

                    foreach (array_filter(explode(',', (string)($srv->peers ?? ''))) as $peerUuid) {
                        $peerUuid = trim($peerUuid);
                        $peer     = $peerNames[$peerUuid] ?? null;
                        if (!$peer) {
                            continue;
                        }
                        // Extract first IP from allowed-IPs (strip prefix)
                        $rawIp = preg_replace('/\/\d+.*/', '', trim(explode(',', $peer['tunnel'])[0]));
                        if (!filter_var($rawIp, FILTER_VALIDATE_IP)) {
                            continue;
                        }
                        $cId        = 'vpnc_wg_' . preg_replace('/[^a-zA-Z0-9]/', '_', $rawIp);
                        $nodes[$cId] = [
                            'id'       => $cId,
                            'type'     => 'vpn_client',
                            'label'    => $this->sanitise($peer['name'] ?: $rawIp),
                            'ip'       => $this->sanitise($rawIp),
                            'hostname' => $this->sanitise($peer['name']),
                            'proto'    => 'WireGuard',
                        ];
                        $links[] = ['source' => $nodeId, 'target' => $cId];
                    }
                }
            }
        } catch (\Throwable $e) {
            // WireGuard plugin not installed or schema mismatch — skip silently
        }

        // Inject links as a sentinel key consumed by buildTopology()
        $nodes['__vpn_links__'] = $links;
        return $nodes;
    }

    private function readOpenVpnClients(int $vpnId): array
    {
        foreach ([
            "/tmp/openvpn_server{$vpnId}_status.log",
            "/var/etc/openvpn/server{$vpnId}.status",
        ] as $path) {
            if (!is_file($path) || !is_readable($path)) {
                continue;
            }
            $content = @file_get_contents($path);
            if (!$content || strpos($content, 'ROUTING TABLE') === false) {
                continue;
            }
            return $this->parseOpenVpnStatus($content);
        }
        return [];
    }

    private function parseOpenVpnStatus(string $content): array
    {
        $clients   = [];
        $inRouting = false;
        foreach (explode("\n", $content) as $line) {
            $line = trim($line);
            if ($line === 'ROUTING TABLE')                         { $inRouting = true;  continue; }
            if ($line === 'GLOBAL STATS' || $line === 'END')      { $inRouting = false; continue; }
            if (!$inRouting || strpos($line, 'Virtual Address') === 0) { continue; }
            $parts = explode(',', $line);
            if (count($parts) < 2) {
                continue;
            }
            $ip = trim($parts[0]);
            $cn = trim($parts[1]);
            if (filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
                $clients[$ip] = $cn;
            }
        }
        return $clients;
    }

    // -------------------------------------------------------------------------

    private function getConfiguredInterfaces(): array
    {
        $result = [];
        $config = Config::getInstance()->object();
        if (empty($config->interfaces)) {
            return $result;
        }

        foreach ($config->interfaces->children() as $tag => $intf) {
            $ipaddr = trim((string)($intf->ipaddr ?? ''));
            $subnet = trim((string)($intf->subnet ?? ''));
            $descr  = trim((string)($intf->descr  ?? strtoupper((string)$tag)));
            $device = trim((string)($intf->if     ?? ''));

            if ($ipaddr === '' || in_array($ipaddr, ['dhcp', 'dhcp6', 'pppoe'], true)) {
                continue;
            }
            if (!filter_var($ipaddr, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
                continue;
            }
            if ((int)$subnet < 1 || (int)$subnet > 32) {
                continue;
            }

            $result[(string)$tag] = [
                'descr'  => $this->sanitise($descr ?: strtoupper((string)$tag)),
                'cidr'   => $ipaddr . '/' . $subnet,
                'ipaddr' => $ipaddr,
                'subnet' => (int)$subnet,
                'device' => $device,
            ];
        }

        return $result;
    }

    /**
     * Parse /var/db/dnsmasq.leases + static DHCP mappings from config.xml.
     * Returns [ ip => hostname ] — only entries with a real (non-'*') hostname.
     *
     * Lease format: <expiry> <mac> <ip> <hostname> <client-id>
     */
    private function getHostnames(): array
    {
        $out = [];

        // Dynamic leases — format: <expiry> <mac> <ip> <hostname> <client-id>
        $leasesFile = '/var/db/dnsmasq.leases';
        if (is_readable($leasesFile)) {
            foreach (file($leasesFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
                $parts = preg_split('/\s+/', trim($line));
                if (count($parts) < 4) {
                    continue;
                }
                $ip       = $parts[2];
                $hostname = $parts[3];
                if ($hostname === '*' || !filter_var($ip, FILTER_VALIDATE_IP)) {
                    continue;
                }
                $out[$ip] = $hostname;
            }
        }

        // Unbound PTR entries — includes DNS host overrides + DHCP registrations.
        // Format: local-data-ptr: "ip hostname"
        $unboundFile = '/var/unbound/host_entries.conf';
        if (is_readable($unboundFile)) {
            foreach (file($unboundFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
                $line = trim($line);
                if (strncmp($line, 'local-data-ptr:', 15) !== 0) {
                    continue;
                }
                // Extract the quoted value: local-data-ptr: "ip hostname"
                if (!preg_match('/"([^"]+)"/', $line, $m)) {
                    continue;
                }
                $parts    = preg_split('/\s+/', $m[1], 2);
                $ip       = $parts[0] ?? '';
                $hostname = $parts[1] ?? '';
                if ($hostname && filter_var($ip, FILTER_VALIDATE_IP)) {
                    $out[$ip] = $hostname;
                }
            }
        }

        // Static DHCP mappings from config.xml take precedence
        try {
            $config = Config::getInstance()->object();
            foreach ((array)($config->dhcpd ?? []) as $iface) {
                foreach ((array)($iface->staticmap ?? []) as $map) {
                    $ip       = trim((string)($map->ipaddr   ?? ''));
                    $hostname = trim((string)($map->hostname  ?? ''));
                    if ($ip && $hostname && filter_var($ip, FILTER_VALIDATE_IP)) {
                        $out[$ip] = $hostname;
                    }
                }
            }
        } catch (\Throwable $e) {
            // config unreadable — dynamic leases only
        }

        return $out;
    }

    /**
     * Map hostwatch physical device name (e.g. igc1, vlan0.160) to
     * a subnet node ID by matching against the <if> field in config.xml.
     */
    private function resolveSubnet(string $ifname, array $interfaces): ?string
    {
        foreach ($interfaces as $tag => $intf) {
            if (($intf['device'] ?? '') === $ifname) {
                return 'net_' . $tag;
            }
        }
        return null;
    }

    // -------------------------------------------------------------------------

    /**
     * Read discovered hosts from hostwatch SQLite DB.
     *
     * Uses SQLite3 class — OPNsense 26.x has sqlite3 extension but not
     * pdo_sqlite. Opens SQLITE3_OPEN_READONLY (no WAL conflicts).
     *
     * Real schema (v_hosts view):
     *   ip_address, interface_name, ether_address,
     *   organization_name (from OUI join), first_seen, last_seen
     */
    private function getHostwatchHosts(): array
    {
        if (!is_file(self::DB_PATH) || !is_readable(self::DB_PATH)) {
            return [];
        }

        try {
            $db = new \SQLite3(self::DB_PATH, SQLITE3_OPEN_READONLY);
            $db->busyTimeout(5000);

            $result = $db->query(
                'SELECT ip_address,
                        interface_name,
                        ether_address,
                        organization_name,
                        first_seen,
                        last_seen
                 FROM   v_hosts
                 ORDER  BY last_seen DESC
                 LIMIT  ' . self::HOST_LIMIT
            );

            if ($result === false) {
                $db->close();
                return [];
            }

            $rows = [];
            while ($row = $result->fetchArray(SQLITE3_ASSOC)) {
                $rows[] = $row;
            }

            $db->close();
            return $rows;

        } catch (\Exception $e) {
            return [];
        }
    }

    // -------------------------------------------------------------------------

    private function isCacheFresh(): bool
    {
        if (!is_file(self::CACHE_FILE)) {
            return false;
        }
        $mtime = @filemtime(self::CACHE_FILE);
        return $mtime !== false && (time() - $mtime) < self::CACHE_TTL;
    }

    private function writeCache(array $data): void
    {
        $tmp = self::CACHE_FILE . '.tmp';
        if (@file_put_contents($tmp, json_encode($data), LOCK_EX) !== false) {
            @rename($tmp, self::CACHE_FILE);
        }
    }

    private function sanitise(string $value): string
    {
        return htmlspecialchars($value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
    }
}
