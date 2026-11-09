#!/usr/bin/env python3
"""Two to four actual Godot processes over a reproducible impaired UDP link, no root/tc.

python qa/test_network.py --latency 45 --jitter 20 --loss .05 --scenario story
Latency/jitter are milliseconds per direction. This does not configure ZeroTier.
"""
import argparse
import heapq
import json
from pathlib import Path
import random
import shutil
import selectors
import socket
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--latency', type=float, default=0)
    parser.add_argument('--jitter', type=float, default=0)
    parser.add_argument('--loss', type=float, default=0)
    parser.add_argument('--scenario', choices=['story', 'stress', 'disconnect', 'host_dead', 'restart', 'host_leave'], default='story')
    parser.add_argument('--label', default='local')
    parser.add_argument('--players', type=int, choices=[2, 3, 4], default=2)
    parser.add_argument('--slow-seat', type=int, default=0)
    parser.add_argument('--slow-extra', type=float, default=200, help='extra one-way latency for slow-seat')
    parser.add_argument('--blackout-seat', type=int, default=0, help='0 affects all links; otherwise only this guest')
    parser.add_argument('--engine', default=str(ROOT / '.tools/Godot_v4.7.2-stable_linux.x86_64'))
    parser.add_argument('--visual', action='store_true')
    parser.add_argument('--exported', action='store_true', help='release template: no path overrides, cwd outside project')
    parser.add_argument('--blackout', type=float, default=0, help='seconds of packet loss at game t=3.5, after all peers load')
    args = parser.parse_args()
    temporary = tempfile.TemporaryDirectory(prefix='survivors-network-')
    ready_path = Path(temporary.name) / 'ready'
    rng = random.Random(724)
    selector = selectors.DefaultSelector()
    links = []
    for seat in range(1, args.players):
        link = {'seat': seat, 'destination': None}
        for direction in ['downstream', 'upstream']:
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            sock.bind(('127.0.0.1', 0))
            sock.setblocking(False)
            link[direction] = sock
            selector.register(sock, selectors.EVENT_READ, (link, direction))
        links.append(link)
    probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    probe.bind(('127.0.0.1', 0))
    host_port = probe.getsockname()[1]
    probe.close()
    processes, logs, queue = [], [], []
    serial, packets, dropped, max_packet = 0, 0, 0, 0
    label = f'{args.label}_{args.scenario}'
    participants = [('host', 0, host_port)] + [
        ('guest' if link['seat'] == 1 else f"guest{link['seat']}", link['seat'], link['downstream'].getsockname()[1])
        for link in links]
    try:
        for role, seat, port in participants:
            log = (ROOT / f'qa/coop_{label}_{role}.log').open('w')
            logs.append(log)
            display = ['--display-driver', 'wayland'] if args.visual else ['--headless']
            path_args = [] if args.exported else ['--path', str(ROOT)]
            command = [args.engine, *display, *path_args,
                       '--', '--coop-probe', f'--role={role}', f'--test-port={port}',
                       f'--scenario={args.scenario}', f'--seat={seat}', f'--players={args.players}',
                       f'--ready-file={ready_path}',
                       f'--report={ROOT}/qa/coop_{label}_{role}.json']
            if args.visual:
                command.append('--visual')
            (ROOT / f'qa/coop_{label}_{role}.json').unlink(missing_ok=True)
            processes.append(subprocess.Popen(command, cwd='/tmp' if args.exported else ROOT, stdout=log, stderr=subprocess.STDOUT))
            if role == 'host':
                time.sleep(.5)
        deadline = time.monotonic() + 30
        link_started = time.monotonic()
        game_started = None
        while any(p.poll() is None for p in processes) and time.monotonic() < deadline:
            current = time.monotonic()
            if game_started is None and ready_path.exists():
                game_started = current
            while queue and queue[0][0] <= current:
                _, _, sock, packet, address = heapq.heappop(queue)
                sock.sendto(packet, address)
            for event, _ in selector.select(.002):
                sock = event.fileobj
                packet, address = sock.recvfrom(65536)
                packets += 1
                max_packet = max(max_packet, len(packet))
                link, direction = event.data
                if direction == 'downstream':
                    link['destination'] = address
                    out, target = link['upstream'], ('127.0.0.1', host_port)
                else:
                    if link['destination'] is None:
                        continue
                    out, target = link['downstream'], link['destination']
                link_time = time.monotonic() - game_started if game_started is not None else -1
                blackout = (args.blackout and 3.5 <= link_time < 3.5 + args.blackout
                            and args.blackout_seat in [0, link['seat']])
                if rng.random() < args.loss or blackout:
                    dropped += 1
                    continue
                extra = args.slow_extra if args.slow_seat == link['seat'] else 0
                delay = max(0, args.latency + extra + rng.uniform(-args.jitter, args.jitter)) / 1000
                serial += 1
                heapq.heappush(queue, (current + delay, serial, out, packet, target))
        for process in processes:
            if process.poll() is None:
                process.kill()
            process.wait()
    finally:
        for process in processes:
            if process.poll() is None:
                process.kill()
        for log in logs:
            log.close()
        selector.close()
        for link in links:
            link['downstream'].close()
            link['upstream'].close()
        temporary.cleanup()
    result = dict(vars(args), packets=packets, dropped=dropped, max_udp_datagram=max_packet,
                  returncodes=[p.returncode for p in processes])
    result['runtime_errors'] = {}
    for role, _, _ in participants:
        path = ROOT / f'qa/coop_{label}_{role}.json'
        if path.exists():
            result[role] = json.loads(path.read_text())
            prefix = Path(result[role].get('diagnostic_prefix', '/missing/prefix'))
            destination = ROOT / 'qa/network_logs'
            destination.mkdir(exist_ok=True)
            for old in destination.glob(f'{label}_{role}_*.jsonl'):
                old.unlink()
            copies = []
            for source in sorted(prefix.parent.glob(prefix.name + '_*.jsonl')):
                target = destination / f'{label}_{role}_{len(copies):03d}.jsonl'
                shutil.copyfile(source, target)
                copies.append(str(target.relative_to(ROOT)))
            result[role]['diagnostic_files'] = copies
            rows = [json.loads(line) for copy in copies for line in (ROOT / copy).read_text().splitlines() if line]
            samples = [row for row in rows if row.get('event') == 'sample']
            result[role]['checks']['live_metrics_saved'] = len(samples) >= 3 and any('frame_ms' in row.get('metrics', {}) for row in samples)
            result[role]['checks']['lag_marker_saved'] = any(row.get('event') == 'user_marker' for row in rows)
        errors = [line for line in (ROOT / f'qa/coop_{label}_{role}.log').read_text().splitlines()
                  if 'ERROR:' in line]
        if errors:
            result['runtime_errors'][role] = errors
    (ROOT / f'qa/coop_{label}_network.json').write_text(json.dumps(result, indent=2, ensure_ascii=False))
    print(json.dumps(result, indent=2, ensure_ascii=False))
    complete = all(role in result and result[role].get('checks') and all(result[role]['checks'].values())
                   for role, _, _ in participants)
    if result['returncodes'] != [0] * args.players or result['runtime_errors'] or not complete:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
