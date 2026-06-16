# Just-Bash

A curated collection of standalone Bash scripts prepared for execution through the Iranux Windows application.

## Iranux compatibility

All Bash files in this repository declare **Iranux Bash Script Standard v1.1** metadata inside the script itself. Each file is self-describing and contains:

- strict JSON in one `IRANUX_METADATA` block;
- a stable script ID, name, version, description, risk level, and requirements;
- supported operating-system identifiers;
- `ui.category` and `ui.action` information for application grouping;
- one canonical Pictogrammers Material Design Icon name in `ui.icon`;
- zero or more `IRANUX_PARAM` blocks for automatic form generation;
- the successful-path marker `__IRANUX_REACHED_END_V1__`.

The Bash file is the authoritative source. No external manifest is required.

## Application discovery hierarchy

Iranux can organise the scripts as follows:

```text
Supported operating system
└── Category
    └── Action
        └── Script button: MDI icon + script name
```

The application reads `requirements.supported_os`, `ui.category`, `ui.action`, `ui.icon`, and `script.name` locally before sending the selected complete Bash script through its existing SSH connection.

## Script catalogue

| Script | Category | Action | MDI icon |
|---|---|---|---|
| StormDNS Server Linux Installer Extended | Network Services | DNS Tunnel Servers | `server-network` |
| Cloudflare API Token Auto Parking | DNS and Domains | Cloudflare Zone Management | `cloud-outline` |
| Cloudflare Global Key Fixed Order | DNS and Domains | Cloudflare Zone Management | `key-variant` |
| Iranux Special Tunnel Ultimate Setup | Network Services | SSH Tunnel Installers | `vpn` |
| MasterDnsVPN Server | Network Services | DNS Tunnel Servers | `dns` |
| s-ui Alireza Installer | Proxy Management | Management Panel Installers | `view-dashboard-outline` |
| StormDNS Server Linux Installer | Network Services | DNS Tunnel Servers | `server-network` |
| x-ui Alireza Installer | Proxy Management | Management Panel Installers | `view-dashboard-outline` |
| 3x-ui Iranux-Compatible Installer | Proxy Management | Management Panel Installers | `view-dashboard` |

## StormDNS duplicate cleanup

The original uppercase `StormDNS-Server(Iranux Compatible).sh` file contained an AI conversion wrapper, raw conversion-report text, Markdown-formatted URLs and service names, invalid line continuations, a duplicate script ID, and a malformed final marker. It was not safely executable Bash.

The v1.1 migration rebuilds that duplicate from the repository's clean lowercase StormDNS implementation, then assigns it the distinct identity `stormdns-server-linux-installer-extended`. This preserves a functional StormDNS action under both existing filenames without retaining corrupted generated text or duplicate IDs.

## Parameters and form generation

Each input is described in an independent strict-JSON `IRANUX_PARAM` block. Iranux should generate form controls from the declared type, display labels and descriptions, apply defaults and validation, and protect sensitive values.

The normal Iranux path is non-interactive. The application collects values before execution and supplies them through its existing secure execution layer. Script logic reads the corresponding uppercase Bash variables, such as:

```bash
CF_DOMAIN="${CF_DOMAIN:-}"
PANEL_PORT="${PANEL_PORT:-}"
```

## Remote execution

The scripts are standalone. They do not require a shared runner or library to be installed on the server. Iranux may send the entire selected Bash file over the active SSH connection, stream standard output and standard error, capture the remote exit code, and detect the final Iranux marker.

The standard does not prescribe a particular SSH library or parameter-transport mechanism. The application remains responsible for safe value transport, privilege selection, timeout, cancellation, output streaming, and audit history.

## Validation

See [`IRANUX-V1.1-VALIDATION.md`](IRANUX-V1.1-VALIDATION.md) for the generated validation report.

The repository migration validates:

- strict JSON metadata and parameter blocks;
- required Iranux v1.1 UI fields;
- unique script IDs and parameter names;
- consistent Category and Action mappings;
- approved canonical MDI icon names;
- Bash syntax with `bash -n`;
- final-marker presence;
- removal of stale certification and conversion-report wrappers.

These files are **Iranux Compatible candidates**. They do not contain manually generated `IRANUX_CERTIFICATION` blocks. Verification and certification remain the responsibility of the official Iranux Validator.

## Migration tooling

The deterministic migration and collection validator are retained under `tools/` for auditability and future maintenance. They are not required by the target Linux server at execution time.
