#!/usr/bin/env python3
"""Upgrade the Just-Bash script collection to Iranux Bash Script Standard v1.1.

The upgrader is intentionally metadata-focused. It preserves Bash logic, removes
known conversion-report wrappers, invalidates any stale certification, adds v1.1
UI metadata, fixes the standard final marker, and validates the resulting files.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]

METADATA_RE = re.compile(
    r": <<'IRANUX_METADATA'\n(?P<json>.*?)\nIRANUX_METADATA",
    re.DOTALL,
)
PARAM_RE = re.compile(
    r": <<'IRANUX_PARAM'\n(?P<json>.*?)\nIRANUX_PARAM",
    re.DOTALL,
)
CERT_RE = re.compile(
    r"\n?: <<'IRANUX_CERTIFICATION'\n.*?\nIRANUX_CERTIFICATION\n?",
    re.DOTALL,
)
ID_RE = re.compile(r"^[a-z][a-z0-9-]*$")
PARAM_NAME_RE = re.compile(r"^[a-z][a-z0-9_]*$")
ICON_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
FINAL_MARKER = '__IRANUX_REACHED_END_V1__'


@dataclass(frozen=True)
class UiMapping:
    category_id: str
    category_name: str
    action_id: str
    action_name: str
    icon: str
    replacement_script_id: str | None = None
    replacement_script_name: str | None = None


MAPPINGS: dict[str, UiMapping] = {
    'StormDNS-Server(Iranux Compatible).sh': UiMapping(
        'network-services', 'Network Services',
        'dns-tunnel-servers', 'DNS Tunnel Servers',
        'server-network',
        'stormdns-server-linux-installer-extended',
        'StormDNS Server Linux Installer Extended',
    ),
    'cloudflare-api-token-auto-parking(Iranux Compatible).sh': UiMapping(
        'dns-and-domains', 'DNS and Domains',
        'cloudflare-zone-management', 'Cloudflare Zone Management',
        'cloud-outline',
    ),
    'cloudflare-global-key-fixed-order(Iranux Compatible).sh': UiMapping(
        'dns-and-domains', 'DNS and Domains',
        'cloudflare-zone-management', 'Cloudflare Zone Management',
        'key-variant',
    ),
    'iranux-special-tunnel-ultimate-setup(Iranux Compatible).sh': UiMapping(
        'network-services', 'Network Services',
        'ssh-tunnel-installers', 'SSH Tunnel Installers',
        'vpn',
    ),
    'masterdnsvpn-server(Iranux Compatible).sh': UiMapping(
        'network-services', 'Network Services',
        'dns-tunnel-servers', 'DNS Tunnel Servers',
        'dns',
    ),
    's-ui-alireza(Iranux Compatible).sh': UiMapping(
        'proxy-management', 'Proxy Management',
        'management-panel-installers', 'Management Panel Installers',
        'view-dashboard-outline',
    ),
    'stormdns-server(Iranux Compatible).sh': UiMapping(
        'network-services', 'Network Services',
        'dns-tunnel-servers', 'DNS Tunnel Servers',
        'server-network',
    ),
    'x-ui-alireza(Iranux Compatible).sh': UiMapping(
        'proxy-management', 'Proxy Management',
        'management-panel-installers', 'Management Panel Installers',
        'view-dashboard-outline',
    ),
    'x-ui-install(Iranux Compatible).sh': UiMapping(
        'proxy-management', 'Proxy Management',
        'management-panel-installers', 'Management Panel Installers',
        'view-dashboard',
    ),
}

# Canonical MDI names verified against Pictogrammers MaterialDesign-SVG.
APPROVED_ICONS = {
    'cloud-outline',
    'dns',
    'key-variant',
    'server-network',
    'view-dashboard',
    'view-dashboard-outline',
    'vpn',
}

REQUIRED_METADATA_PATHS = (
    ('standard', 'name'),
    ('standard', 'schema_version'),
    ('script', 'id'),
    ('script', 'name'),
    ('script', 'version'),
    ('script', 'description'),
    ('risk', 'level'),
    ('ui', 'category', 'id'),
    ('ui', 'category', 'name'),
    ('ui', 'action', 'id'),
    ('ui', 'action', 'name'),
    ('ui', 'icon', 'library'),
    ('ui', 'icon', 'name'),
)


def get_nested(value: dict[str, Any], path: tuple[str, ...]) -> Any:
    current: Any = value
    for part in path:
        if not isinstance(current, dict) or part not in current:
            raise KeyError('.'.join(path))
        current = current[part]
    return current


def clean_generated_wrapper(text: str) -> str:
    """Remove the known non-Bash conversion wrapper without changing script logic."""
    begin = '=== IRANUX_REWRITTEN_SCRIPT_BEGIN ==='
    end = '=== IRANUX_REWRITTEN_SCRIPT_END ==='
    if begin in text:
        text = text.split(begin, 1)[1].lstrip('\r\n')
    if end in text:
        text = text.split(end, 1)[0].rstrip() + '\n'

    # Defensive cleanup: a shebang must be the first line of an executable script.
    if not text.startswith('#!'):
        index = text.find('#!')
        if index < 0:
            raise ValueError('No Bash shebang found')
        text = text[index:]

    return text.replace('\r\n', '\n').replace('\r', '\n')


def upgrade_metadata(text: str, filename: str) -> str:
    matches = list(METADATA_RE.finditer(text))
    if len(matches) != 1:
        raise ValueError(f'{filename}: expected exactly one IRANUX_METADATA block, found {len(matches)}')

    match = matches[0]
    metadata = json.loads(match.group('json'))
    mapping = MAPPINGS[filename]

    metadata.setdefault('standard', {})['name'] = 'iranux-script-metadata'
    metadata['standard']['schema_version'] = '1.1'

    if mapping.replacement_script_id:
        metadata.setdefault('script', {})['id'] = mapping.replacement_script_id
    if mapping.replacement_script_name:
        metadata.setdefault('script', {})['name'] = mapping.replacement_script_name

    metadata['ui'] = {
        'category': {
            'id': mapping.category_id,
            'name': mapping.category_name,
        },
        'action': {
            'id': mapping.action_id,
            'name': mapping.action_name,
        },
        'icon': {
            'library': 'mdi',
            'name': mapping.icon,
        },
    }

    replacement = ": <<'IRANUX_METADATA'\n" + json.dumps(
        metadata,
        indent=2,
        ensure_ascii=False,
    ) + '\nIRANUX_METADATA'

    return text[:match.start()] + replacement + text[match.end():]


def ensure_marker(text: str) -> str:
    # Correct a known malformed marker produced by an earlier conversion.
    text = text.replace('**IRANUX_REACHED_END_V1**', FINAL_MARKER)

    if FINAL_MARKER not in text:
        text = text.rstrip() + f'\n\necho "{FINAL_MARKER}"\n'
    return text


def upgrade_file(path: Path) -> bool:
    original = path.read_text(encoding='utf-8-sig')
    updated = clean_generated_wrapper(original)
    updated = CERT_RE.sub('\n', updated)
    updated = upgrade_metadata(updated, path.name)
    updated = ensure_marker(updated)
    updated = updated.rstrip() + '\n'

    if updated == original.replace('\r\n', '\n').replace('\r', '\n'):
        return False

    path.write_text(updated, encoding='utf-8', newline='\n')
    return True


def validate_metadata(metadata: dict[str, Any], filename: str) -> None:
    for path in REQUIRED_METADATA_PATHS:
        get_nested(metadata, path)

    if metadata['standard']['name'] != 'iranux-script-metadata':
        raise ValueError(f'{filename}: invalid standard.name')
    if metadata['standard']['schema_version'] != '1.1':
        raise ValueError(f'{filename}: schema version is not 1.1')
    if not ID_RE.fullmatch(metadata['script']['id']):
        raise ValueError(f'{filename}: invalid script.id')

    ui = metadata['ui']
    for key in ('category', 'action'):
        if not ID_RE.fullmatch(ui[key]['id']):
            raise ValueError(f'{filename}: invalid ui.{key}.id')
        if not isinstance(ui[key]['name'], str) or not ui[key]['name'].strip():
            raise ValueError(f'{filename}: empty ui.{key}.name')

    if ui['icon']['library'] != 'mdi':
        raise ValueError(f'{filename}: icon library must be mdi')
    icon = ui['icon']['name']
    if not ICON_RE.fullmatch(icon) or icon not in APPROVED_ICONS:
        raise ValueError(f'{filename}: unknown or invalid approved MDI icon: {icon!r}')


def validate_file(path: Path) -> tuple[str, str, str, str, int]:
    text = path.read_text(encoding='utf-8')
    if not text.startswith('#!'):
        raise ValueError(f'{path.name}: shebang is not the first line')
    if '=== IRANUX_' in text:
        raise ValueError(f'{path.name}: conversion-report wrapper remains')
    if list(CERT_RE.finditer(text)):
        raise ValueError(f'{path.name}: stale certification block remains')

    metadata_matches = list(METADATA_RE.finditer(text))
    if len(metadata_matches) != 1:
        raise ValueError(f'{path.name}: invalid metadata block count')
    metadata = json.loads(metadata_matches[0].group('json'))
    validate_metadata(metadata, path.name)

    parameter_names: set[str] = set()
    for param_match in PARAM_RE.finditer(text):
        parameter = json.loads(param_match.group('json'))
        for required in ('name', 'label', 'description', 'type', 'required'):
            if required not in parameter:
                raise ValueError(f'{path.name}: parameter missing {required}')
        name = parameter['name']
        if not isinstance(name, str) or not PARAM_NAME_RE.fullmatch(name):
            raise ValueError(f'{path.name}: invalid parameter name {name!r}')
        if name in parameter_names:
            raise ValueError(f'{path.name}: duplicate parameter name {name!r}')
        parameter_names.add(name)

    if FINAL_MARKER not in text:
        raise ValueError(f'{path.name}: final marker is missing')

    subprocess.run(['bash', '-n', str(path)], check=True)

    return (
        metadata['script']['id'],
        metadata['ui']['category']['id'],
        metadata['ui']['action']['id'],
        metadata['ui']['icon']['name'],
        len(parameter_names),
    )


def write_report(rows: list[tuple[str, str, str, str, str, int]]) -> None:
    lines = [
        '# Iranux v1.1 Validation Report',
        '',
        'All Bash scripts in this repository were validated as Iranux Compatible v1.1 candidates.',
        '',
        '| File | Script ID | Category | Action | MDI Icon | Parameters |',
        '|---|---|---|---|---|---:|',
    ]
    for filename, script_id, category, action, icon, count in rows:
        lines.append(f'| `{filename}` | `{script_id}` | `{category}` | `{action}` | `{icon}` | {count} |')

    lines.extend([
        '',
        'Validation performed:',
        '',
        '- strict JSON parsing for every `IRANUX_METADATA` and `IRANUX_PARAM` block;',
        '- Iranux schema version 1.1 and required UI metadata checks;',
        '- unique script ID, Category, Action, and parameter-name consistency;',
        '- approved canonical Pictogrammers MDI icon checks;',
        '- Bash syntax validation with `bash -n`;',
        '- final-marker presence;',
        '- stale certification and conversion-wrapper removal.',
        '',
        'These scripts are Compatible candidates only. No `IRANUX_CERTIFICATION` block was generated.',
        '',
    ])
    (ROOT / 'IRANUX-V1.1-VALIDATION.md').write_text('\n'.join(lines), encoding='utf-8', newline='\n')


def validate_collection() -> list[tuple[str, str, str, str, str, int]]:
    expected = set(MAPPINGS)
    actual = {path.name for path in ROOT.glob('*.sh')}
    if actual != expected:
        missing = sorted(expected - actual)
        extra = sorted(actual - expected)
        raise ValueError(f'Unexpected script set. Missing={missing}, Extra={extra}')

    rows: list[tuple[str, str, str, str, str, int]] = []
    script_ids: set[str] = set()
    category_names: dict[str, str] = {}
    action_mappings: dict[str, tuple[str, str]] = {}

    for filename in sorted(MAPPINGS):
        path = ROOT / filename
        script_id, category_id, action_id, icon, param_count = validate_file(path)
        metadata = json.loads(METADATA_RE.search(path.read_text(encoding='utf-8')).group('json'))  # type: ignore[union-attr]

        if script_id in script_ids:
            raise ValueError(f'Duplicate script ID: {script_id}')
        script_ids.add(script_id)

        category_name = metadata['ui']['category']['name']
        old_category_name = category_names.setdefault(category_id, category_name)
        if old_category_name != category_name:
            raise ValueError(f'Conflicting category name for {category_id}')

        action_name = metadata['ui']['action']['name']
        old_action = action_mappings.setdefault(action_id, (category_id, action_name))
        if old_action != (category_id, action_name):
            raise ValueError(f'Conflicting action mapping for {action_id}')

        rows.append((filename, script_id, category_id, action_id, icon, param_count))

    return rows


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true', help='Validate only; do not modify scripts.')
    args = parser.parse_args()

    changed: list[str] = []
    if not args.check:
        for filename in sorted(MAPPINGS):
            if upgrade_file(ROOT / filename):
                changed.append(filename)

    rows = validate_collection()
    write_report(rows)

    print(f'Validated {len(rows)} Iranux v1.1 Bash scripts.')
    print(f'Changed {len(changed)} scripts.')
    for filename in changed:
        print(f'  - {filename}')
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (ValueError, KeyError, json.JSONDecodeError, subprocess.CalledProcessError) as exc:
        print(f'ERROR: {exc}', file=sys.stderr)
        raise SystemExit(1)
