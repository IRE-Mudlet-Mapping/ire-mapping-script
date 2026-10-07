#!/usr/bin/env python3
"""Run the shipped XML scripts against a fake Mudlet map (Lua 5.1/LuaJIT)."""
import json
import pathlib
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET

root = pathlib.Path(__file__).resolve().parents[1]
runtime = shutil.which('luajit') or shutil.which('lua5.1')
if not runtime:
    raise SystemExit('Install LuaJIT or Lua 5.1 to run these tests.')
xml = ET.parse(root / 'mudlet-mapper.xml')
scripts = {e.findtext('name'): e.findtext('script') or '' for e in xml.iter('Script')}
aliases = {e.findtext('name'): e.findtext('script') or '' for e in xml.iter('Alias')}
with tempfile.TemporaryDirectory(prefix='mapper-batching-tests-') as directory:
    folder = pathlib.Path(directory)
    for name, code in {
        'batch': scripts['Crowdmap session batching'],
        'service': scripts['Crowdmap service'],
        'toggle': aliases['Toggle mapping mode'],
        'save': scripts['mmp.saveOptions'],
        'load': scripts['mmp.loadOptions'],
        'settings': scripts['mconfig settings functions'],
        'download': scripts['mmp.downloadedFile'],
        'mapper_aliases': next(code for code in scripts.values() if 'function mmp.doareadelete(' in code),
    }.items():
        (folder / (name + '.lua')).write_text(code)
    # Parse every shipped script/alias/trigger with the actual target Lua version.
    syntax_checks = []
    for i, element in enumerate(xml.iter('script')):
        code = element.text or ''
        path = folder / f'syntax-{i}.lua'
        path.write_text(code)
        syntax_checks.append('assert(loadfile(' + json.dumps(str(path), ensure_ascii=False) + '))')
    (folder / 'syntax.lua').write_text('\n'.join(syntax_checks))
    subprocess.run([runtime, str(folder / 'syntax.lua')], check=True)
    subprocess.run([runtime, str(root / 'tests/crowdmap_batching.lua'), directory], check=True)
