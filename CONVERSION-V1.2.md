# Conversion to Iranux Script Specification v1.2

Date: 2026-10-07. Method: the converter prompt `prompts/convert-to-iranux-specification.md`
of the specification repository, applied to the v1.1 scripts of this catalog. The rule
was to change only what the specification requires; anything else that looked wrong is
listed below as a question, not changed.

## Repository-wide changes

- Files renamed to `<script.id>.sh` (Catalog profile rule 16.8). Script ids and versions
  are unchanged, so admin catalog settings and earlier runs still match.
- `StormDNS-Server(Iranux Compatible).sh` removed: it was byte-identical to the
  lowercase StormDNS file apart from its id (`stormdns-server-linux-installer-extended`)
  and name.
- Every script: `schema_version` 1.2, Persian name, description and parameter text,
  `estimated_minutes`, `basic`/`advanced` levels, end-user English descriptions, one
  `IRANUX_RESULT` line before the final marker (outputs with an empty value are left
  out; no secret is ever in it), the specification's `iranux_json_string` helper.
- `required_commands` lists only commands a script needs and does not install itself.
- Option labels stay English: v1.2 has no `i18n` for options (question for v1.3).

## Validation result

All 8 scripts parse as **Compatible** in the Iranux application parser
(`BashScriptRunner.Core` `IranuxScriptParser`, Develop at 469a799), `bash -n` and
`shellcheck -S error` pass, and no new shellcheck warnings were added. Sample
`IRANUX_RESULT` lines from each script were parsed with `IranuxResultParser` with no
errors. `check_fixtures.py --profile catalog` reports only these errors:

| File | Line | Finding | Status |
|---|---:|---|---|
| `s-ui-alireza-installer.sh` | 427, 436 | `wget --no-check-certificate` | Kept from the original. Owner decision (question 1). |
| `x-ui-alireza-installer.sh` | 359, 368, 393 | `wget --no-check-certificate` | Kept from the original. Owner decision (question 1). |
| `iranux-ultimate-setup-port-22.sh` | 696 | plain `http://` download (bot speed test) | Kept from the original. Owner decision (question 1). |
| `iranux-ultimate-setup-port-22.sh` | 202–204 | IRX1611 on `fuser -k` | False positive: `-k` kills the process on a port; it is not curl's `-k`. Checker fix needed. |
| `masterdnsvpn-server-linux-installer.sh` | 468–469 | IRX1611 on `fuser -k` | Same false positive. |
| `stormdns-server-linux-installer.sh` | 659–660 | IRX1611 on `fuser -k` | Same false positive. |

Warnings: IRX1234 for `iranux-ultimate-setup-port-22.sh` (12 minutes; the web runner now
allows twice the estimate, at most 60 minutes), and IRX1802 where a result line is built
at run time (s-ui, x-ui, 3x-ui) so the checker cannot read it statically.

## Risk levels

| Script | Level | Why (specification §12) |
|---|---|---|
| Cloudflare API token | high | Writes DNS zones and records in an external Cloudflare account and deletes duplicate records. |
| Cloudflare Global API Key | high | Writes DNS zones and records in an external Cloudflare account. |
| s-ui (Alireza) | high | Full system package upgrade on non-Debian systems; stops the existing `sing-box` service. |
| x-ui (Alireza) | high | Full system package upgrade on several systems; replaces its own `/usr/local/x-ui*` folders. |
| 3x-ui | dangerous | Deletes folders it did not create: an existing `/root/cert/<domain>` before issuing a certificate, `/root/cert/ip` on failure, and the operator-given install folder on reinstall. Without those it would be medium. No firewall or SSH edits. |
| Iranux special tunnel (port 22) | dangerous | `userdel --force -r` on existing accounts, `rm -rf` of `/etc/bot` and `/etc/SSHPlus`, SSH `Port 22` and `PasswordAuthentication yes`, `ufw --force reset`, stops nginx, apache2 and caddy. |
| MasterDnsVPN | dangerous | Replaces core DNS on port 53: edits `resolved.conf`, stops and disables other DNS services and systemd-resolved, kills processes on port 53. |
| StormDNS | dangerous | Same as MasterDnsVPN, plus a system-wide block of outgoing TCP to port 53. |

Four of eight scripts are `dangerous`, so the web wizard refuses them under the current
policy. Whether to allow `dangerous` scripts (for example with an explicit confirmation)
is the owner's decision (KI-43 item 12).

## Edits next to behaviour (please review)

1. **Cloudflare API token script, `main`:** `local DOMAIN USER_IP CF_ACCOUNT_ID CF_API_TOKEN`
   hid the account id and token that the runner exports, so every Iranux run stopped
   with "Required value missing: cf_account_id". The line now keeps the exported values
   (`CF_ACCOUNT_ID="${CF_ACCOUNT_ID:-}" CF_API_TOKEN="${CF_API_TOKEN:-}"`), which is the
   converter's "assign it from the upper-case variable" rule. Tested with a mocked
   `curl`: the run reaches the end and the token is not in the log.
2. **Generated secrets no longer printed:** s-ui and x-ui (Alireza) and 3x-ui write a
   generated admin login (and the 3x-ui API token) to `/root/s-ui-credentials.txt`,
   `/root/x-ui-credentials.txt` with `umask 077` and print the file name. MasterDnsVPN and
   StormDNS print the path of `encrypt_key.txt` instead of the key.
3. **Tunnel script:** `chmod 600` on `config.env` before the bot token is appended
   (specification §10.1.4). The bot service and the `iranux` tool run as root.
4. **3x-ui:** the `xui_service_dir` parameter never took effect (the script read
   `$XUI_SERVICE`); it is now read with `XUI_SERVICE` as the fallback.
   `custom_key_path` is now type `path` (it is a file path checked with `-f`, not key
   text). Option `description` keys the schema rejects were removed. `script.name` is
   now "3x-ui Installer" (it contained the status word "Iranux-Compatible"; the id is
   unchanged).
5. **Quoting (converter §5.7):** unquoted parameter expansions were quoted;
   `install_x-ui ${TARGET_VERSION}` and `install_s-ui ${TARGET_VERSION}` became an
   if/else; option strings built by concatenation became arrays (s-ui `params`, 3x-ui
   `domain_args`).
6. `clear` removed from the main path (Cloudflare scripts, tunnel script). The `clear` inside the
   `iranux` menu tool that the tunnel script installs on the server is kept.
7. StormDNS `user_domain` was `required: true` although the script works without it;
   now optional, as in MasterDnsVPN.
8. `required_commands` lists only what a script needs and does not install itself:
   `[]` for the Cloudflare scripts and 3x-ui (they install `curl`, `jq`, `tar` and `openssl` when missing),
   `["apt-get", "systemctl"]` for the tunnel script, `["systemctl"]` for the others.
9. 3x-ui: when the panel is bound to localhost, the panel address in the result is plain
   text, not a link (it opens only through an SSH tunnel).

## Questions for the owner

1. **TLS checks:** remove `--no-check-certificate` from the s-ui and x-ui downloads and
   use an https source for the tunnel bot's speed test? Until then the Validator will
   not certify those three scripts (IRX1611).
2. **`dangerous` scripts:** allow them in the web wizard with a confirmation step, or
   keep them refused (KI-43 item 12)?
3. **Tunnel script user deletion:** it deletes every account with UID 1000 or more
   except `admin` and the login user. In an Iranux run the login user is `root`, so
   default image accounts such as `ubuntu` or `debian` are deleted with their home
   folders. Keep, or limit to tunnel users?
4. **Tunnel management menu:** `iranux` on the server opens a menu (create, delete, list
   users, user info, server status) that an Iranux run never reaches. The same tool has
   non-interactive forms (`iranux /add`, `/del`, `/list`, `/info`, `/status`). Suggested:
   a separate low-risk management script with an `action` parameter.
5. **`curl | bash` / `curl | sh`:** NodeSource setup in the tunnel script (line 248) and
   `get.acme.sh` in 3x-ui (lines 894, 1129). Kept (IRX1612 warnings).
6. **Secrets on command lines** (visible in `ps`): Cloudflare token and Global API Key in
   curl headers, panel passwords to `sui admin` / `x-ui setting`, PostgreSQL password in
   `psql -c`, the bot token in the Telegram API URL. Kept.
7. **s-ui:** with "Configure panel settings" Yes and "Change admin" No, `sui admin -show`
   prints the current login to the log. Move it to the root-only file as well?
8. **s-ui / x-ui OS tests:** s-ui tests `oracle`, which is not an os-release id; real
   Oracle Linux (`ol`) falls through to apt-get. `supported_os` says `ol`. Fix the case
   statement? `parch`, `armbian` and `virtuozzo` are kept because the scripts test for them.
9. **Arch family:** the first `pacman -Syu` has no `--noconfirm` (s-ui, x-ui, 3x-ui) and
   may wait for input.
10. **3x-ui:** `panel_port` has no `generate` because the script uses it only when
    "Choose panel port" is Yes; `ssl_setup_method` and `ssl_domain` stay basic because
    they change what is installed (specification §7.9.2); "Try again" after a failed
    PostgreSQL install repeats forever; when SSL setup fails the printed URL still says
    https.
11. **DNS tunnels:** `IFS=$'\n\t'` makes unquoted `$EXECUTABLE_ARGS`, `$delete_rule` and
    `$rule` one argument each (key generation probably falls back to the older method;
    redirect-rule deletion probably never works). `rm -f *.spec` removes any `.spec`
    file in the working folder. The StormDNS egress block of outgoing TCP/53 is not
    removed on uninstall. StormDNS "Use local files" needs files already in the working
    folder, which the web runner cannot provide: hide it? The two scripts name their
    action parameter differently (`install_action`, `action`); kept so saved runs match.
12. **Estimates** are guesses: 2 minutes (Cloudflare), 5 (s-ui, x-ui, DNS tunnels),
    10 (3x-ui), 12 (tunnel, full `apt-get upgrade` plus a BadVPN build).
13. **3x-ui file name** keeps the id `x-ui-installer-iranux-compatible`, which contains
    the words "iranux-compatible". Changing the id would orphan admin catalog settings;
    rename it together with a data migration if wanted.
14. **Encryption key file** (MasterDnsVPN, StormDNS): `encrypt_key.txt` is written by the
    vendor binary in the working folder with a mode the script does not set. Add
    `chmod 600`?
15. **Option labels** stay English (no option `i18n` in v1.2), while the Persian
    descriptions name «بله» and «خیر». Add option translations in v1.3?
16. **Checker false positive:** IRX1611 matches `fuser -k`; restrict the `-k` pattern to
    `curl`/`wget` in `tools/check_fixtures.py` of the specification repository.
