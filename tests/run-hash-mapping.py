#!/usr/bin/env python3
"""Run hash regressions against embedded mapper Lua with modeled native APIs."""
import os
from pathlib import Path
import subprocess
import tempfile
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
package = ET.parse(root / 'mudlet-mapper.xml').getroot()
code = '\n'.join(node.text or '' for node in package.iter('script'))
# Load complete functions from the package, preserving their actual control flow.
def function(start, end):
    return code[code.index(start):code.index(end, code.index(start))]

with tempfile.TemporaryDirectory() as directory:
    source = Path(directory) / 'hash-functions.lua'
    chunks = [function('  function setRoomIDbyHash(', '  function setRoomUserData('),
              function('function mmp.roomidFromHash(', 'function mmp.mappingNewroom(')]
    for name in ('mmp.centerRoominfo', 'mmp.speedwalking', 'mmp.mappingNewroom'):
        script = next(node.text for node in package.iter('script')
                      if node.text and ('function ' + name + '(') in node.text)
        if name == 'mmp.speedwalking':
            script = script[script.index('function mmp.speedwalking('):script.index('function doSpeedWalk(')]
        if name == 'mmp.mappingNewroom':
            script = script[script.index('function mmp.mappingNewroom('):]
        chunks.append(script)
    source.write_text('''local function pack(...) return {n=select('#', ...), ...} end
local function unpackResults(r) return unpack(r, 1, r.n) end
local service = testService
local original = testOriginal
''' + '\n'.join(chunks))
    subprocess.run([os.environ.get('LUA', 'lua'), str(root / 'tests/hash-mapping.lua'), str(source)], check=True)
