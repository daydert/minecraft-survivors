#!/usr/bin/env python3
"""Summarize local cooperative JSONL logs (files, folders or a ZIP) without uploading them.

python scripts/analyze_coop_logs.py path/to/logs.zip --output report.json
"""
import argparse
from collections import Counter
import json
from pathlib import Path
import zipfile


def sources(paths):
    for path in paths:
        path = Path(path)
        if path.is_dir():
            yield from sources(sorted(path.rglob('*.jsonl')))
        elif path.suffix.lower() == '.zip':
            with zipfile.ZipFile(path) as archive:
                for entry in archive.infolist():
                    if entry.filename.endswith('.jsonl') and entry.file_size <= 8 * 1024 * 1024:
                        with archive.open(entry) as stream:
                            yield f'{path.name}:{entry.filename}', stream.read().decode('utf-8', errors='replace').splitlines()
        elif path.suffix == '.jsonl':
            yield str(path), path.read_text(encoding='utf-8', errors='replace').splitlines()


def analyze(paths):
    sessions, damaged = {}, []
    for name, lines in sources(paths):
        current = None
        for number, line in enumerate(lines, 1):
            if not line or len(line) > 32768:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                damaged.append({'file': name, 'line': number})
                continue
            if not isinstance(row, dict):
                continue
            kind = row.get('event')
            if kind == 'log_part':
                identity = row.get('session', name)
                current = sessions.setdefault(identity, {
                    'role': row.get('role'), 'nick': row.get('nick'), 'version': row.get('version'),
                    'os': row.get('os'), 'gpu': row.get('gpu'), 'files': [], 'samples': 0,
                    'events': Counter(), 'metric_max': {}, 'peer_rtt_max_ms': {},
                    'markers': [], 'runs': [], 'end_reasons': [], 'writer_drops': 0,
                })
                current['files'].append(name)
            if current is None:
                continue
            current['events'][kind] += 1
            if kind == 'run_start':
                current['runs'].append({key: row.get(key) for key in ['seed', 'epoch', 'roster']})
            elif kind == 'user_marker':
                current['markers'].append({key: row.get(key) for key in ['t_ms', 'wall_ms', 'epoch', 'tick', 'state', 'snapshot_age_ms', 'pending', 'correction_px']})
            elif kind == 'session_end':
                current['end_reasons'].append(row.get('reason'))
            elif kind == 'sample':
                current['samples'] += 1
                current['writer_drops'] = max(current['writer_drops'], row.get('writer', {}).get('dropped', 0))
                for metric, value in row.get('metrics', {}).items():
                    current['metric_max'][metric] = max(current['metric_max'].get(metric, 0), value.get('max', 0))
                for peer in row.get('peers', []):
                    key = str(peer['id'])
                    current['peer_rtt_max_ms'][key] = max(current['peer_rtt_max_ms'].get(key, 0), peer.get('rtt_ms', 0))
    return {'sessions': sessions, 'damaged_lines': damaged}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('paths', nargs='+')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    result = analyze(args.paths)
    text = json.dumps(result, indent=2, ensure_ascii=False)
    if args.output:
        args.output.write_text(text, encoding='utf-8')
    else:
        print(text)


if __name__ == '__main__':
    main()
