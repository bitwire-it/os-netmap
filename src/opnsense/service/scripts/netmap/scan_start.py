#!/usr/local/bin/python3

"""
scan_start.py — netmap plugin, invoked by configd as root.

configd passes parameters as separate argv items via shlex split,
so sys.argv[1] = ip, sys.argv[2] = job_id.

Validates both, sets up job directory, spawns scan_run.py fully
detached, returns {"status":"started"} immediately.
"""

import sys
import os
import json
import re
import ipaddress
import subprocess
import time
import grp

JOB_DIR    = '/tmp/netmap_jobs'
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))


def validate_ipv4(raw: str) -> str:
    addr = ipaddress.IPv4Address(raw.strip())
    if addr.is_loopback or addr.is_multicast or addr.is_reserved or addr.is_unspecified:
        raise ValueError(f'Disallowed address type: {addr}')
    return str(addr)


def validate_job_id(raw: str) -> str:
    cleaned = raw.strip().lower()
    if not re.match(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        cleaned,
    ):
        raise ValueError(f'Invalid job ID: {raw!r}')
    return cleaned


def setup_job_dir() -> None:
    try:
        www_gid = grp.getgrnam('www').gr_gid
    except (KeyError, AttributeError):
        www_gid = 80
    os.makedirs(JOB_DIR, exist_ok=True)
    os.chown(JOB_DIR, 0, www_gid)
    os.chmod(JOB_DIR, 0o750)


def cleanup_stale_jobs(max_age_s: int = 3600) -> None:
    cutoff = time.time() - max_age_s
    try:
        for fname in os.listdir(JOB_DIR):
            fpath = os.path.join(JOB_DIR, fname)
            try:
                if os.path.isfile(fpath) and os.path.getmtime(fpath) < cutoff:
                    os.unlink(fpath)
            except OSError:
                pass
    except OSError:
        pass


def main() -> None:
    if len(sys.argv) < 3:
        print(json.dumps({'error': 'Missing arguments: expected <ip> <job_id>'}))
        sys.exit(1)

    try:
        ip     = validate_ipv4(sys.argv[1])
        job_id = validate_job_id(sys.argv[2])
    except (ValueError, ipaddress.AddressValueError) as exc:
        print(json.dumps({'error': str(exc)}))
        sys.exit(1)

    setup_job_dir()
    cleanup_stale_jobs()

    runner = os.path.join(SCRIPT_DIR, 'scan_run.py')
    if not os.path.isfile(runner):
        print(json.dumps({'error': 'scan_run.py not found at ' + runner}))
        sys.exit(1)

    subprocess.Popen(
        [sys.executable, runner, ip, job_id],
        close_fds=True,
        start_new_session=True,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    print(json.dumps({'status': 'started', 'job_id': job_id}))


if __name__ == '__main__':
    main()
