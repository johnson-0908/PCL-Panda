"""Inspect a release ZIP without extracting it or printing matched private values."""
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import sys
import zipfile
from audit_public import PATTERNS, ROOT


def main():
    package = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / 'artifacts/release/PCL2-Revived-win-x64.zip'
    failures = []
    private_roots = [str(ROOT), str(ROOT.parent), os.environ.get('USERPROFILE', '')]
    with zipfile.ZipFile(package) as archive:
        names = archive.namelist()
        if len(names) != len(set(name.lower() for name in names)):
            failures.append({'rule': 'duplicate-zip-entry'})
        manifest = json.loads(archive.read('update-manifest.json').decode('utf-8-sig'))
        expected = {item['name']: item for item in manifest['files']}
        if set(names) != set(expected) | {'update-manifest.json'} or manifest['schema'] != 1:
            failures.append({'rule': 'manifest-set-mismatch'})
        for name in names:
            if PurePosixPath(name).name != name or '\\' in name or ':' in name:
                failures.append({'file': name, 'rule': 'non-flat-path'})
            data = archive.read(name)
            if name in expected:
                entry = expected[name]
                if len(data) != entry['size'] or hashlib.sha256(data).hexdigest() != entry['sha256'].lower():
                    failures.append({'file': name, 'rule': 'manifest-hash-or-size'})
            for rule, pattern in PATTERNS.items():
                if pattern.search(data):
                    failures.append({'file': name, 'rule': rule})
            for private in private_roots:
                if private and any(value.encode(encoding).lower() in data.lower()
                                   for value in {private, private.replace('\\', '/')}
                                   for encoding in ('utf-8', 'utf-16le')):
                    failures.append({'file': name, 'rule': 'developer-local-path'})
    print(json.dumps({'status': 'FAIL' if failures else 'PASS', 'files': len(names),
                      'version': manifest['version'], 'findings': failures}, ensure_ascii=False, indent=2))
    return bool(failures)


if __name__ == '__main__':
    raise SystemExit(main())
