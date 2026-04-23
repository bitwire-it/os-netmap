<?php

/*
 * Copyright (C) 2026 os-netmap contributors
 * All rights reserved.
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * GET /api/netmap/flow/summary[?window=<seconds>]
 *   window: 300 → 5-min DB, 3600 → hourly DB, else daily DB (default 86400)
 *
 * Reads OPNsense Insight (NetFlow) SQLite databases from /var/netflow/.
 * Requires "Capture Local" enabled in Reporting → NetFlow → Settings.
 *
 * Real schema (verified on OPNsense 26.x):
 *   Table: timeserie
 *   Columns: mtime, last_seen (unix ts), if, src_addr, direction, octets, packets
 *   direction is 'in' or 'out' — octets are per direction per row.
 *
 * Uses SQLite3 class (not PDO). Opens SQLITE3_OPEN_READONLY.
 * Cache is per-period (120 s TTL).
 */

namespace OPNsense\Netmap\Api;

use OPNsense\Base\ApiControllerBase;

class FlowController extends ApiControllerBase
{
    private const NETFLOW_DIR = '/var/netflow';
    private const CACHE_TTL   = 120;

    // Ordered by granularity: pick the finest DB that covers the requested window.
    // Key = max window seconds this DB is suitable for; value = [db path, cutoff].
    private const WINDOW_MAP = [
           300 => ['/var/netflow/src_addr_000300.sqlite',    300],
          3600 => ['/var/netflow/src_addr_003600.sqlite',   3600],
        604800 => ['/var/netflow/src_addr_086400.sqlite',  86400],  // daily DB for 1d–7d
    ];

    // -------------------------------------------------------------------------

    public function summaryAction(): array
    {
        $window = (int)$this->request->getQuery('window', 'int', 86400);
        if ($window < 1) $window = 86400;

        // Pick the finest-granularity DB that covers the requested window.
        [$dbPath, $cutoff] = ['/var/netflow/src_addr_086400.sqlite', 86400];
        foreach (self::WINDOW_MAP as $maxWindow => $cfg) {
            if ($window <= $maxWindow) {
                [$dbPath, $cutoff] = $cfg;
                break;
            }
        }

        $cacheFile = '/tmp/netmap_flow_' . $window . '.json';

        if ($this->isCacheFresh($cacheFile)) {
            $cached = @file_get_contents($cacheFile);
            if ($cached !== false) {
                $decoded = json_decode($cached, true);
                if (is_array($decoded)) {
                    return $decoded;
                }
            }
        }

        $result = $this->buildSummary($dbPath, $cutoff);
        $this->writeCache($cacheFile, $result);
        return $result;
    }

    // -------------------------------------------------------------------------

    private function buildSummary(string $dbPath, int $cutoff): array
    {
        if (!is_dir(self::NETFLOW_DIR)) {
            return ['available' => false, 'reason' => 'NetFlow directory not found'];
        }

        if (!is_file($dbPath) || !is_readable($dbPath) || filesize($dbPath) < 512) {
            return [
                'available' => false,
                'reason'    => 'No NetFlow data for this window. Enable Capture Local in Reporting → NetFlow.',
            ];
        }

        $data = $this->queryDb($dbPath, $cutoff);
        if ($data === null || count($data) === 0) {
            return [
                'available' => false,
                'reason'    => 'No NetFlow data. Enable Capture Local in Reporting → NetFlow.',
            ];
        }

        return ['available' => true, 'hosts' => $data];
    }

    // -------------------------------------------------------------------------

    /**
     * Query a src_addr SQLite DB.
     *
     * Schema: timeserie(mtime, last_seen, if, src_addr, direction, octets, packets)
     *   - last_seen  : unix epoch integer
     *   - direction  : 'in' | 'out'
     *   - octets     : bytes for this direction in this time bucket
     *
     * SUM octets per src_addr per direction over the requested cutoff window,
     * then pivot in/out into separate columns.
     */
    private function queryDb(string $path, int $cutoffSeconds): ?array
    {
        try {
            $db = new \SQLite3($path, SQLITE3_OPEN_READONLY);
            $db->busyTimeout(3000);

            $cutoff = time() - $cutoffSeconds;

            $stmt = $db->prepare("
                SELECT
                    src_addr AS ip,
                    SUM(CASE WHEN direction = 'in'  THEN octets ELSE 0 END) AS bytes_in,
                    SUM(CASE WHEN direction = 'out' THEN octets ELSE 0 END) AS bytes_out,
                    SUM(packets) AS flows
                FROM timeserie
                WHERE last_seen >= :cutoff
                GROUP BY src_addr
                ORDER BY SUM(octets) DESC
                LIMIT 5000
            ");

            if ($stmt === false) {
                $db->close();
                return null;
            }

            $stmt->bindValue(':cutoff', $cutoff, SQLITE3_INTEGER);
            $res = $stmt->execute();

            if ($res === false) {
                $db->close();
                return null;
            }

            $result = [];
            while ($row = $res->fetchArray(SQLITE3_ASSOC)) {
                $ip = trim((string)($row['ip'] ?? ''));
                if (!filter_var($ip, FILTER_VALIDATE_IP)) {
                    continue;
                }
                $result[$ip] = [
                    'in'    => (int)($row['bytes_out'] ?? 0),  // direction='out' = router→host = download
                    'out'   => (int)($row['bytes_in']  ?? 0),  // direction='in'  = host→router = upload
                    'flows' => (int)($row['flows']     ?? 0),
                ];
            }

            $db->close();
            return $result;

        } catch (\Exception $e) {
            return null;
        }
    }

    // -------------------------------------------------------------------------

    private function isCacheFresh(string $cacheFile): bool
    {
        if (!is_file($cacheFile)) {
            return false;
        }
        $mtime = @filemtime($cacheFile);
        return $mtime !== false && (time() - $mtime) < self::CACHE_TTL;
    }

    private function writeCache(string $cacheFile, array $data): void
    {
        $tmp = $cacheFile . '.tmp';
        if (@file_put_contents($tmp, json_encode($data), LOCK_EX) !== false) {
            @rename($tmp, $cacheFile);
        }
    }
}
