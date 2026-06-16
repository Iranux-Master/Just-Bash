#!/usr/bin/env python3
"""Prepare the duplicate StormDNS file from the clean implementation, then run migration."""

from __future__ import annotations

import importlib.util
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CLEAN = ROOT / 'stormdns-server(Iranux Compatible).sh'
EXTENDED = ROOT / 'StormDNS-Server(Iranux Compatible).sh'
MODULE_PATH = ROOT / 'tools' / 'upgrade_to_iranux_v11.py'


def load_upgrader():
    spec = importlib.util.spec_from_file_location('iranux_v11_upgrader', MODULE_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError('Unable to load Iranux v1.1 upgrader.')
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def main() -> int:
    if not CLEAN.is_file():
        raise FileNotFoundError(CLEAN)

    shutil.copyfile(CLEAN, EXTENDED)

    upgrader = load_upgrader()
    upgrader.repair_known_source_defects = lambda text, filename: text
    sys.argv = [str(MODULE_PATH)]
    return int(upgrader.main())


if __name__ == '__main__':
    raise SystemExit(main())
