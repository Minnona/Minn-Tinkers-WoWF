"""Detect TOC version changes and build the installable release ZIP."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from zipfile import ZIP_DEFLATED, ZipFile

ADDON = 'Minn Tinkers WoWF'
TOC = Path(ADDON + '.toc')
ASSET = Path('dist/Minn-Tinkers-WoWF.zip')


def version(text):
    values = re.findall(r'^##\s*Version:\s*(.*?)\s*$', text, re.MULTILINE)
    if len(values) != 1 or not re.fullmatch(r'[0-9]+(?:\.[0-9]+){1,2}', values[0]):
        raise ValueError('TOC must contain one numeric Version, such as 1.0 or 1.0.1')
    return values[0]


if __name__ == '__main__':
    current = version(TOC.read_text(encoding='utf-8-sig'))
    if sys.argv[1] == 'check':
        event = json.loads(Path(os.environ['GITHUB_EVENT_PATH']).read_text())
        before = event.get('before', '')
        previous = None
        if os.environ['GITHUB_EVENT_NAME'] == 'push' and before.strip('0'):
            subprocess.run(['git', 'cat-file', '-e', before + '^{commit}'], check=True)
            old = subprocess.run(['git', 'show', before + ':' + str(TOC)], capture_output=True, text=True)
            if old.returncode == 0:
                previous = version(old.stdout)
        publish = os.environ['GITHUB_EVENT_NAME'] == 'workflow_dispatch' or current != previous
        with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
            output.write(f'publish={str(publish).lower()}\nversion={current}\n')
        print(f'TOC version: {previous or "none"} -> {current}; publish={publish}')
    elif sys.argv[1] == 'package':
        tracked = subprocess.check_output(['git', 'ls-files', '-z']).decode().split('\0')
        excluded = {'AGENTS.MD', 'DESIGN.md', '.gitignore'}
        files = [name for name in tracked if name and name not in excluded
                 and Path(name).parts[0] not in {'.github', 'Tests'}]
        for line in TOC.read_text(encoding='utf-8-sig').splitlines():
            entry = line.strip().replace('\\', '/')
            if entry and not entry.startswith('#') and entry not in files:
                raise ValueError('TOC entry missing from release: ' + entry)
        for required in (str(TOC), 'README.md', 'LICENSE'):
            if required not in files:
                raise ValueError('Required release file missing: ' + required)
        ASSET.parent.mkdir(exist_ok=True)
        with ZipFile(ASSET, 'w', ZIP_DEFLATED) as archive:
            for name in sorted(files):
                archive.write(name, ADDON + '/' + name)
        print(f'Built {ASSET} for {current}: {len(files)} files under {ADDON}/')
    else:
        raise SystemExit('Use check or package')
