#!/usr/local/bin/python3

"""
scan_run.py — netmap plugin.
Detached child of scan_start.py. Never called directly by the web layer.
Runs nmap via subprocess list (no shell), parses XML, writes result atomically.
"""

import sys
import os
import json
import re
import ipaddress
import subprocess
import tempfile
import time
import grp
import xml.etree.ElementTree as ET

NMAP_BIN    = '/usr/local/bin/nmap'
JOB_DIR     = '/tmp/netmap_jobs'
MAX_RUNTIME = 90
TOP_PORTS   = 1000


def validate_ipv4(raw: str) -> str:
    addr = ipaddress.IPv4Address(raw.strip())
    if addr.is_loopback or addr.is_multicast or addr.is_reserved or addr.is_unspecified:
        raise ValueError(f'Disallowed address: {addr}')
    return str(addr)


def validate_job_id(raw: str) -> str:
    cleaned = raw.strip().lower()
    if not re.match(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        cleaned,
    ):
        raise ValueError('Invalid job ID')
    return cleaned


def run_nmap(ip: str) -> str:
    if not os.path.isfile(NMAP_BIN):
        raise FileNotFoundError(f'nmap not found at {NMAP_BIN}')

    cmd = [
        NMAP_BIN,
        '-n', '-Pn', '-sV', '-O', '--osscan-guess',
        '-T4',
        f'--host-timeout={MAX_RUNTIME}s',
        '--max-retries=2',
        '--open',
        f'--top-ports={TOP_PORTS}',
        '-oX', '-',
        ip,
    ]

    result = subprocess.run(cmd, capture_output=True, text=True, timeout=MAX_RUNTIME + 15)

    if result.returncode not in (0, 1):
        raise RuntimeError(f'nmap exited {result.returncode}: {result.stderr[:300]!r}')
    if not result.stdout.strip():
        raise RuntimeError('nmap produced no output')

    return result.stdout


def parse_nmap_xml(xml_str: str) -> dict:
    try:
        root = ET.fromstring(xml_str)
    except ET.ParseError as exc:
        raise ValueError(f'Failed to parse nmap XML: {exc}') from exc

    out: dict = {
        'ports':      [],
        'os':         None,
        'uptime_s':   None,
        'scanned_at': int(time.time()),
    }

    host_el = root.find('host')
    if host_el is None:
        return out

    for port_el in host_el.findall('./ports/port'):
        state_el = port_el.find('state')
        if state_el is None or state_el.get('state') != 'open':
            continue
        svc = port_el.find('service')
        out['ports'].append({
            'port':     _sint(port_el.get('portid'), 0),
            'protocol': _cap(port_el.get('protocol', 'tcp'), 8),
            'service':  _cap(svc.get('name',    '') if svc is not None else '', 32),
            'product':  _cap(svc.get('product', '') if svc is not None else '', 64),
            'version':  _cap(svc.get('version', '') if svc is not None else '', 32),
        })

    os_matches = host_el.findall('./os/osmatch')
    if os_matches:
        best = max(os_matches, key=lambda x: _sint(x.get('accuracy', '0'), 0))
        out['os'] = {
            'name':     _cap(best.get('name', ''), 128),
            'accuracy': _sint(best.get('accuracy', '0'), 0),
        }

    uptime_el = host_el.find('uptime')
    if uptime_el is not None:
        out['uptime_s'] = _sint(uptime_el.get('seconds', ''), None)

    return out


def write_result(job_id: str, payload: dict, *, is_error: bool = False) -> None:
    try:
        www_gid = grp.getgrnam('www').gr_gid
    except (KeyError, AttributeError):
        www_gid = 80

    final  = os.path.join(JOB_DIR, job_id + ('.error' if is_error else '.json'))
    fd, tmp = tempfile.mkstemp(dir=JOB_DIR, suffix='.tmp')
    try:
        with os.fdopen(fd, 'w') as fh:
            json.dump(payload, fh)
        os.chown(tmp, 0, www_gid)
        os.chmod(tmp, 0o640)
        os.rename(tmp, final)
    except Exception:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def _cap(v: str, n: int) -> str:
    return str(v)[:n]


def _sint(v, default):
    try:
        return int(v)
    except (TypeError, ValueError):
        return default


def main() -> None:
    if len(sys.argv) < 3:
        sys.exit(1)

    try:
        ip     = validate_ipv4(sys.argv[1])
        job_id = validate_job_id(sys.argv[2])
    except (ValueError, ipaddress.AddressValueError):
        sys.exit(1)

    try:
        write_result(job_id, parse_nmap_xml(run_nmap(ip)))
    except Exception as exc:
        try:
            write_result(job_id, {'message': str(exc)[:256]}, is_error=True)
        except Exception:
            pass
        sys.exit(1)


if __name__ == '__main__':
    main()
