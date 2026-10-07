#!/usr/bin/env python3
"""Reproduce filename literal handling through the actual syntax-check runner."""
import os
import pathlib
import subprocess
import sys
import tempfile

with tempfile.TemporaryDirectory(prefix='mapper-runner-') as parent:
    directory = pathlib.Path(parent) / "témп路径 with spaces"
    directory.mkdir()
    env = dict(os.environ, TMPDIR=str(directory))
    result = subprocess.run([sys.executable, str(pathlib.Path(__file__).with_name('run.py'))],
                            env=env, capture_output=True, text=True, errors='replace')
    if result.returncode:
        print(result.stdout)
        print(result.stderr)
        raise SystemExit(result.returncode)
    print('PASS syntax runner with a non-ASCII temporary-directory path')
