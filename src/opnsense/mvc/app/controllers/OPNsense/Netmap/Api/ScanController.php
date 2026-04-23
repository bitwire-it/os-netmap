<?php

/*
 * Copyright (C) 2026 os-netmap contributors
 * All rights reserved.
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * POST /api/netmap/scan/start  { "target": "<ipv4>" }
 * GET  /api/netmap/scan/poll?job_id=<uuid>
 *
 * Security:
 *   1. Target: valid IPv4, within a locally configured subnet only.
 *   2. Rate limit: one scan per IP per 300 s (SQLite3 rate DB).
 *   3. Job IDs: UUID v4 generated server-side; user job_id strict regex before fs access.
 *   4. IP passed as validated atom to configdRun() — never shell-interpolated.
 *   5. All POST endpoints CSRF-protected by ApiControllerBase.
 *
 * Uses SQLite3 class — pdo_sqlite absent in OPNsense 26.x.
 */

namespace OPNsense\Netmap\Api;

use OPNsense\Base\ApiControllerBase;
use OPNsense\Core\Backend;
use OPNsense\Core\Config;

class ScanController extends ApiControllerBase
{
    private const JOB_DIR      = '/tmp/netmap_jobs';
    private const RATE_DB      = '/var/db/netmap_rate.sqlite';
    private const RATE_LIMIT_S = 300;

    // -------------------------------------------------------------------------

    public function startAction(): array
    {
        if (!$this->request->isPost()) {
            return ['error' => 'POST required'];
        }

        $target = trim((string)$this->request->getPost('target', 'striptags', ''));

        if (!filter_var($target, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
            return ['error' => 'Invalid IPv4 address'];
        }
        if (!$this->isLocalTarget($target)) {
            return ['error' => 'Target is not within any configured local network'];
        }
        if ($this->isRateLimited($target)) {
            return ['error' => 'Rate limit active — please wait before rescanning', 'retry_after' => self::RATE_LIMIT_S];
        }

        $jobId = $this->generateUUID();

        if (!is_dir(self::JOB_DIR) && !@mkdir(self::JOB_DIR, 0700, true)) {
            return ['error' => 'Could not create job directory'];
        }

        $pendingFile = self::JOB_DIR . '/' . $jobId . '.pending';
        if (@file_put_contents($pendingFile, (string)time(), LOCK_EX) === false) {
            return ['error' => 'Could not write job marker'];
        }

        $backend  = new Backend();
        $response = json_decode(
            trim($backend->configdRun('netmap scan_async ' . $target . ' ' . $jobId)),
            true
        );

        if (!is_array($response) || ($response['status'] ?? '') !== 'started') {
            @unlink($pendingFile);
            return ['error' => 'Scan daemon failed to start'];
        }

        $this->recordScan($target);
        return ['status' => 'started', 'job_id' => $jobId];
    }

    // -------------------------------------------------------------------------

    public function pollAction(): array
    {
        $jobId = trim((string)$this->request->getQuery('job_id', 'striptags', ''));

        if (!$this->isValidUUID($jobId)) {
            return ['error' => 'Invalid job ID'];
        }

        $jobId       = strtolower($jobId);
        $resultFile  = self::JOB_DIR . '/' . $jobId . '.json';
        $pendingFile = self::JOB_DIR . '/' . $jobId . '.pending';
        $errorFile   = self::JOB_DIR . '/' . $jobId . '.error';

        if (is_file($errorFile)) {
            $decoded = json_decode(@file_get_contents($errorFile) ?: '{}', true);
            @unlink($errorFile);
            @unlink($pendingFile);
            return ['status' => 'error', 'message' => $decoded['message'] ?? 'Scan failed'];
        }

        if (is_file($resultFile)) {
            $data = json_decode(@file_get_contents($resultFile) ?: '{}', true);
            @unlink($resultFile);
            @unlink($pendingFile);
            return ['status' => 'done', 'data' => $data ?? []];
        }

        if (is_file($pendingFile)) {
            return ['status' => 'running'];
        }

        return ['status' => 'unknown'];
    }

    // -------------------------------------------------------------------------

    private function isLocalTarget(string $ip): bool
    {
        $ipLong = ip2long($ip);
        if ($ipLong === false) {
            return false;
        }

        $config = Config::getInstance()->object();
        if (empty($config->interfaces)) {
            return false;
        }

        foreach ($config->interfaces->children() as $intf) {
            $ifIp = trim((string)($intf->ipaddr ?? ''));
            $bits = (int)($intf->subnet ?? 0);

            if ($ifIp === '' || in_array($ifIp, ['dhcp', 'dhcp6', 'pppoe'], true)) {
                continue;
            }
            if (!filter_var($ifIp, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
                continue;
            }
            if ($bits < 1 || $bits > 32) {
                continue;
            }

            $mask    = $bits === 32 ? 0xFFFFFFFF : ~((1 << (32 - $bits)) - 1) & 0xFFFFFFFF;
            $network = ip2long($ifIp) & $mask;

            if (($ipLong & $mask) === $network) {
                return true;
            }
        }

        return false;
    }

    // -------------------------------------------------------------------------

    private function isRateLimited(string $ip): bool
    {
        try {
            $db   = $this->openRateDb();
            $stmt = $db->prepare('SELECT scanned_at FROM scan_times WHERE ip = ? LIMIT 1');
            $stmt->bindValue(1, $ip, SQLITE3_TEXT);
            $res  = $stmt->execute();
            if ($res === false) {
                return false;
            }
            $row = $res->fetchArray(SQLITE3_ASSOC);
            $db->close();
            return $row && (time() - (int)$row['scanned_at']) < self::RATE_LIMIT_S;
        } catch (\Exception $e) {
            return false;
        }
    }

    private function recordScan(string $ip): void
    {
        try {
            $db   = $this->openRateDb();
            $stmt = $db->prepare('INSERT OR REPLACE INTO scan_times (ip, scanned_at) VALUES (?, ?)');
            $stmt->bindValue(1, $ip,    SQLITE3_TEXT);
            $stmt->bindValue(2, time(), SQLITE3_INTEGER);
            $stmt->execute();
            $db->close();
        } catch (\Exception $e) {
            // Non-fatal
        }
    }

    private function openRateDb(): \SQLite3
    {
        $db = new \SQLite3(self::RATE_DB, SQLITE3_OPEN_READWRITE | SQLITE3_OPEN_CREATE);
        $db->busyTimeout(3000);
        $db->exec(
            'CREATE TABLE IF NOT EXISTS scan_times (
                ip         TEXT    PRIMARY KEY NOT NULL,
                scanned_at INTEGER NOT NULL
            )'
        );
        return $db;
    }

    // -------------------------------------------------------------------------

    private function isValidUUID(string $id): bool
    {
        return (bool)preg_match(
            '/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i',
            $id
        );
    }

    private function generateUUID(): string
    {
        $data    = random_bytes(16);
        $data[6] = chr((ord($data[6]) & 0x0f) | 0x40);
        $data[8] = chr((ord($data[8]) & 0x3f) | 0x80);
        return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($data), 4));
    }
}
