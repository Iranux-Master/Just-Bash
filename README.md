# Just-Bash

A curated collection of standalone Bash scripts that the Iranux applications (the
webpack web app and the Iranux Bash Runner Windows app) show and run on a user's server.

The governing specification is the
[Iranux Script Specification](https://github.com/Iranux-Master/Iranux-BashScript-Standard)
(the repository keeps its old name). Every script here declares **schema 1.2**, or
**1.3** when it has a choice parameter (so its options carry Persian labels), and
targets the specification's Catalog profile (§16); the findings still open are listed
in [`CONVERSION-V1.2.md`](CONVERSION-V1.2.md).

## What every script contains

- one strict-JSON `IRANUX_METADATA` block: id, name, version, description,
  `estimated_minutes`, risk level, requirements, supported operating systems, category,
  action and a Material Design Icons name; a script that needs DNS records (the two DNS
  tunnel servers) declares them in a `dns` member (specification v1.3 §5.7), so Setup
  creates them in the user's own DNS when it can;
- Persian (`fa`) name and description for the script, a Persian label and
  description for every parameter, and a Persian label for every option of a choice
  (`options[].i18n.fa.label`, specification v1.3 §7.7), so the setup form reads in
  Persian or English. A yes/no choice is phrased as a question ("Set your own panel
  port?");
- one `IRANUX_PARAM` block per input, marked `basic` or `advanced`; values the script
  can pick itself (such as a random panel port) carry `generate`;
- one `IRANUX_RESULT` line before the final marker with what the user needs at the end
  (panel port and path, username, name servers, where login details are stored), with
  Persian labels. Generated secrets are not printed: generated login details go to a
  file under `/root` that only root can read, and the result names that file;
- the final marker `__IRANUX_REACHED_END_V1__` on every successful path.

The Bash file is the only source of truth. No external manifest is needed. File names
are `<script.id>.sh`.

## Script catalogue

| File | Category / Action | Risk | Minutes | Parameters (basic + advanced) |
|---|---|---|---:|---|
| `cloudflare-api-token-auto-parking.sh` | DNS and Domains / Cloudflare Zone Management | high | 2 | 4 + 0 |
| `cloudflare-global-key-fixed-order-auto-parking.sh` | DNS and Domains / Cloudflare Zone Management | high | 2 | 5 + 0 |
| `iranux-ultimate-setup-port-22.sh` | Network Services / SSH Tunnel Installers | dangerous | 12 | 3 + 0 |
| `masterdnsvpn-server-linux-installer.sh` | Network Services / DNS Tunnel Servers | dangerous | 5 | 2 + 1 |
| `stormdns-server-linux-installer.sh` | Network Services / DNS Tunnel Servers | dangerous | 5 | 2 + 2 |
| `s-ui-alireza-installer.sh` | Proxy Management / Management Panel Installers | high | 5 | 5 + 4 |
| `x-ui-alireza-installer.sh` | Proxy Management / Management Panel Installers | high | 5 | 3 + 1 |
| `x-ui-installer-iranux-compatible.sh` (3x-ui) | Proxy Management / Management Panel Installers | dangerous | 10 | 5 + 19 |

Risk levels follow §12 of the specification (the highest operation on any path wins).
The web app refuses `dangerous` scripts unless an administrator allows them
(`VpsGateway:Scripts:AllowDestructiveScriptsByDefault`). Why each script has its level
is in [`CONVERSION-V1.2.md`](CONVERSION-V1.2.md).

## Remote execution

The scripts are standalone. They need no shared runner or library on the server. The
Iranux application sends the selected file over SSH, passes each parameter as its
upper-case variable (`panel_port` is read as `PANEL_PORT`), streams the output, and reads
the exit code, the `IRANUX_RESULT` line and the final marker. The normal path waits for
no terminal input.

## Validation

Each script is checked with:

```bash
python3 tools/check_fixtures.py --profile catalog <script>.sh   # from Iranux-BashScript-Standard
bash -n <script>.sh
shellcheck -S error <script>.sh
```

and parses as **Compatible** in the Iranux application's own parser. The open items
(kept TLS-skipping downloads, checker false positives, owner questions) are listed in
[`CONVERSION-V1.2.md`](CONVERSION-V1.2.md).

These files are **Iranux Compatible candidates**. They contain no
`IRANUX_CERTIFICATION` block; certification ("Iranux Verified") is issued only by the
Iranux Validator with the Iranux signing key.

## History

`IRANUX-V1.1-VALIDATION.md`, `tools/` and `.github/workflows/upgrade-iranux-v11.yml`
are the earlier v1.1 migration. They describe the old file names and must not be run
against the v1.2 scripts (the v1.1 tool would rewrite them back to schema 1.1).
