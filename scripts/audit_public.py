"""Check tracked (or staged) source, never print a matched credential value.

This is a targeted publication guard, not a complete secret-scanning guarantee.
Run after git add, with --staged, before publishing. Do not add runtime folders.
"""
import argparse
import json
from pathlib import Path, PurePosixPath
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PATTERNS = {
    'github-token': re.compile(rb'(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,})'),
    'private-key': re.compile(rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'),
    'aws-access-id': re.compile(rb'(?:AKIA|ASIA)[A-Z0-9]{16}'),
    'literal-oauth-token': re.compile(rb'(?i)["\'](?:access_token|refresh_token)["\']\s*:\s*["\'][A-Za-z0-9_.-]{30,}'),
}
FORBIDDEN_PARTS = {'.private', '.cache', '.minecraft', 'backups', 'logs', 'bin', 'obj', 'artifacts', 'patches'}
FORBIDDEN_SUFFIXES = {'.pdb', '.pfx', '.key', '.log', '.binlog', '.dmp', '.user', '.suo'}

def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args])

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--staged', action='store_true', help='Read index blobs, not working files')
    parser.add_argument('--deny-value', action='append', default=[], help='Private value to reject; not printed')
    args = parser.parse_args()
    names = [p.decode('utf-8') for p in git('ls-files', '-z').split(b'\0') if p]
    if not names:
        raise SystemExit('No tracked/staged files: initialize the repository and stage only reviewed source first.')
    failures = []
    for name in names:
        path = PurePosixPath(name)
        if (FORBIDDEN_PARTS.intersection(p.lower() for p in path.parts)
            or path.suffix.lower() in FORBIDDEN_SUFFIXES
            or path.name == '.env' or path.name.startswith('.env.')
            or name.startswith('.github/workflows/') or name.startswith('.github/ISSUE_TEMPLATE/')):
            failures.append({'file': name, 'rule': 'private-or-distribution-only-path'})
        if (ROOT / name).is_symlink():
            failures.append({'file': name, 'rule': 'symlink'})
        data = git('show', ':' + name) if args.staged else (ROOT / name).read_bytes()
        for rule, pattern in PATTERNS.items():
            if pattern.search(data):
                failures.append({'file': name, 'rule': rule})
        for value in args.deny_value:
            if value and any(value.encode(enc).lower() in data.lower() for enc in ('utf-8', 'utf-16le')):
                failures.append({'file': name, 'rule': 'explicit-private-value'})
    for required in ('LICENCE', 'MeloongCore/LICENSE.txt', 'README.md', 'PROVENANCE.md', 'docs/AUTHENTICATION.md'):
        if required not in names:
            failures.append({'file': required, 'rule': 'missing-attribution-or-documentation'})
    print(json.dumps({'status': 'FAIL' if failures else 'PASS', 'files': len(names),
                      'staged': args.staged, 'findings': failures}, ensure_ascii=False, indent=2))
    return bool(failures)

if __name__ == '__main__':
    raise SystemExit(main())
