#!/bin/bash

: <<'IRANUX_METADATA'
{
  "standard": {
    "name": "iranux-script-metadata",
    "schema_version": "1.0"
  },
  "script": {
    "id": "x-ui-installer-iranux-compatible",
    "name": "3x-ui Iranux-Compatible Installer",
    "version": "1.0.0",
    "description": "Installs 3x-ui and configures database, panel port, SSL certificate options, and system service without interactive installation prompts."
  },
  "risk": {
    "level": "dangerous"
  },
  "requirements": {
    "requires_root": true,
    "requires_internet": true,
    "supported_os": ["ubuntu", "debian", "armbian", "fedora", "amzn", "virtuozzo", "rhel", "almalinux", "rocky", "ol", "centos", "arch", "manjaro", "parch", "opensuse-tumbleweed", "opensuse-leap", "alpine"],
    "required_commands": ["curl", "tar", "openssl"]
  }
}
IRANUX_METADATA

# ==============================================================================
# IRANUX PARAMETERS
# ==============================================================================

: <<'IRANUX_PARAM'
{
  "name": "xui_main_folder",
  "label": "x-ui Installation Directory",
  "description": "Main directory where x-ui will be installed.",
  "type": "path",
  "required": true,
  "default": "/usr/local/x-ui",
  "example": "/usr/local/x-ui",
  "group": "Installation Paths"
}
IRANUX_PARAM

XUI_MAIN_FOLDER="${XUI_MAIN_FOLDER:-/usr/local/x-ui}"

: <<'IRANUX_PARAM'
{
  "name": "xui_service_dir",
  "label": "Systemd Service Directory",
  "description": "Directory where the x-ui systemd service file will be installed.",
  "type": "path",
  "required": true,
  "default": "/etc/systemd/system",
  "example": "/etc/systemd/system",
  "group": "Installation Paths"
}
IRANUX_PARAM

XUI_SERVICE="${XUI_SERVICE:-/etc/systemd/system}"

: <<'IRANUX_PARAM'
{
  "name": "xui_version",
  "label": "x-ui Version",
  "description": "Optional x-ui release version to install, for example v2.3.5. Leave empty to install the latest release.",
  "type": "string",
  "required": false,
  "placeholder": "v2.3.5",
  "group": "Installation Settings"
}
IRANUX_PARAM

XUI_VERSION="${XUI_VERSION:-${1:-}}"

: <<'IRANUX_PARAM'
{
  "name": "server_ipv4",
  "label": "Server Public IPv4",
  "description": "Optional server public IPv4 address. Used if automatic public IP detection fails.",
  "type": "ipv4",
  "required": false,
  "example": "203.0.113.10",
  "group": "Network Settings"
}
IRANUX_PARAM

SERVER_IPV4="${SERVER_IPV4:-}"

: <<'IRANUX_PARAM'
{
  "name": "database_type",
  "label": "Database Type",
  "description": "Choose the database type for x-ui.",
  "type": "enum",
  "required": true,
  "default": "1",
  "options": [
    {
      "label": "SQLite",
      "value": "1",
      "description": "Default option. Recommended for smaller installations."
    },
    {
      "label": "PostgreSQL",
      "value": "2",
      "description": "Recommended for high client counts or many nodes."
    }
  ],
  "group": "Database Settings"
}
IRANUX_PARAM

DATABASE_TYPE="${DATABASE_TYPE:-1}"

: <<'IRANUX_PARAM'
{
  "name": "postgres_mode",
  "label": "PostgreSQL Mode",
  "description": "Choose how PostgreSQL should be configured if PostgreSQL is selected.",
  "type": "enum",
  "required": false,
  "default": "1",
  "options": [
    {
      "label": "Install PostgreSQL locally",
      "value": "1"
    },
    {
      "label": "Use external PostgreSQL DSN",
      "value": "2"
    }
  ],
  "group": "Database Settings"
}
IRANUX_PARAM

POSTGRES_MODE="${POSTGRES_MODE:-1}"

: <<'IRANUX_PARAM'
{
  "name": "postgres_dsn",
  "label": "PostgreSQL DSN",
  "description": "External PostgreSQL DSN. Required only when PostgreSQL Mode is external.",
  "type": "secret",
  "required": false,
  "placeholder": "postgres://user:pass@host:5432/xui?sslmode=disable",
  "sensitive": true,
  "group": "Database Settings"
}
IRANUX_PARAM

POSTGRES_DSN="${POSTGRES_DSN:-}"

: <<'IRANUX_PARAM'
{
  "name": "postgres_failure_action",
  "label": "PostgreSQL Failure Action",
  "description": "Action to take if local PostgreSQL installation fails.",
  "type": "enum",
  "required": false,
  "default": "4",
  "options": [
    {
      "label": "Retry local install",
      "value": "1"
    },
    {
      "label": "Use external DSN",
      "value": "2"
    },
    {
      "label": "Abort installation",
      "value": "3"
    },
    {
      "label": "Fall back to SQLite",
      "value": "4"
    }
  ],
  "group": "Database Settings"
}
IRANUX_PARAM

POSTGRES_FAILURE_ACTION="${POSTGRES_FAILURE_ACTION:-4}"

: <<'IRANUX_PARAM'
{
  "name": "customize_panel_port",
  "label": "Customize Panel Port",
  "description": "Choose whether to set a custom panel port. If No, a random port is generated.",
  "type": "enum",
  "required": true,
  "default": "N",
  "options": [
    {
      "label": "Yes",
      "value": "Y"
    },
    {
      "label": "No",
      "value": "N"
    }
  ],
  "group": "Panel Settings"
}
IRANUX_PARAM

CUSTOMIZE_PANEL_PORT="${CUSTOMIZE_PANEL_PORT:-N}"

: <<'IRANUX_PARAM'
{
  "name": "panel_port",
  "label": "Panel Port",
  "description": "Custom panel port. Used only when Customize Panel Port is Yes.",
  "type": "port",
  "required": false,
  "example": 2053,
  "group": "Panel Settings"
}
IRANUX_PARAM

PANEL_PORT="${PANEL_PORT:-}"

: <<'IRANUX_PARAM'
{
  "name": "ssl_setup_method",
  "label": "SSL Setup Method",
  "description": "Choose how SSL should be configured for the x-ui panel.",
  "type": "enum",
  "required": true,
  "default": "2",
  "options": [
    {
      "label": "Let's Encrypt for Domain",
      "value": "1"
    },
    {
      "label": "Let's Encrypt for IP Address",
      "value": "2"
    },
    {
      "label": "Custom SSL Certificate",
      "value": "3"
    },
    {
      "label": "Skip SSL",
      "value": "4"
    }
  ],
  "group": "SSL Settings"
}
IRANUX_PARAM

SSL_SETUP_METHOD="${SSL_SETUP_METHOD:-2}"

: <<'IRANUX_PARAM'
{
  "name": "ssl_domain",
  "label": "SSL Domain",
  "description": "Domain name used for Let's Encrypt domain certificate.",
  "type": "domain",
  "required": false,
  "example": "panel.example.com",
  "group": "SSL Settings"
}
IRANUX_PARAM

SSL_DOMAIN="${SSL_DOMAIN:-}"

: <<'IRANUX_PARAM'
{
  "name": "ssl_http_port",
  "label": "Domain Certificate HTTP-01 Port",
  "description": "Local standalone HTTP port used by acme.sh for domain certificate issuance.",
  "type": "port",
  "required": false,
  "default": 80,
  "group": "SSL Settings"
}
IRANUX_PARAM

SSL_HTTP_PORT="${SSL_HTTP_PORT:-80}"

: <<'IRANUX_PARAM'
{
  "name": "ip_cert_http_port",
  "label": "IP Certificate HTTP-01 Port",
  "description": "Local standalone HTTP port used by acme.sh for IP certificate issuance.",
  "type": "port",
  "required": false,
  "default": 80,
  "group": "SSL Settings"
}
IRANUX_PARAM

IP_CERT_HTTP_PORT="${IP_CERT_HTTP_PORT:-80}"

: <<'IRANUX_PARAM'
{
  "name": "ip_cert_alt_http_port",
  "label": "Alternative IP Certificate Port",
  "description": "Alternative local HTTP-01 port if the selected IP certificate port is already in use.",
  "type": "port",
  "required": false,
  "group": "SSL Settings"
}
IRANUX_PARAM

IP_CERT_ALT_HTTP_PORT="${IP_CERT_ALT_HTTP_PORT:-}"

: <<'IRANUX_PARAM'
{
  "name": "ssl_ipv6_address",
  "label": "SSL IPv6 Address",
  "description": "Optional IPv6 address to include in the Let's Encrypt IP certificate.",
  "type": "ipv6",
  "required": false,
  "example": "2001:db8::10",
  "group": "SSL Settings"
}
IRANUX_PARAM

SSL_IPV6_ADDRESS="${SSL_IPV6_ADDRESS:-}"

: <<'IRANUX_PARAM'
{
  "name": "custom_ssl_domain",
  "label": "Custom SSL Domain",
  "description": "Domain name covered by the custom certificate.",
  "type": "domain",
  "required": false,
  "example": "panel.example.com",
  "group": "Custom SSL Settings"
}
IRANUX_PARAM

CUSTOM_SSL_DOMAIN="${CUSTOM_SSL_DOMAIN:-}"

: <<'IRANUX_PARAM'
{
  "name": "custom_cert_path",
  "label": "Custom Certificate Path",
  "description": "Path to an existing certificate file, such as fullchain.pem or .crt.",
  "type": "path",
  "required": false,
  "example": "/root/cert/panel.example.com/fullchain.pem",
  "group": "Custom SSL Settings"
}
IRANUX_PARAM

CUSTOM_CERT_PATH="${CUSTOM_CERT_PATH:-}"

: <<'IRANUX_PARAM'
{
  "name": "custom_key_path",
  "label": "Custom Private Key Path",
  "description": "Path to the private key file for the custom SSL certificate.",
  "type": "private_key",
  "required": false,
  "sensitive": true,
  "example": "/root/cert/panel.example.com/privkey.pem",
  "group": "Custom SSL Settings"
}
IRANUX_PARAM

CUSTOM_KEY_PATH="${CUSTOM_KEY_PATH:-}"

: <<'IRANUX_PARAM'
{
  "name": "bind_panel_localhost",
  "label": "Bind HTTP Panel to Localhost",
  "description": "When SSL is skipped, choose whether the panel should bind to 127.0.0.1 only.",
  "type": "enum",
  "required": false,
  "default": "N",
  "options": [
    {
      "label": "Yes",
      "value": "Y"
    },
    {
      "label": "No",
      "value": "N"
    }
  ],
  "group": "SSL Settings"
}
IRANUX_PARAM

BIND_PANEL_LOCALHOST="${BIND_PANEL_LOCALHOST:-N}"

: <<'IRANUX_PARAM'
{
  "name": "modify_acme_reloadcmd",
  "label": "Modify ACME Reload Command",
  "description": "Choose whether to modify the acme.sh reload command for domain certificates.",
  "type": "enum",
  "required": false,
  "default": "N",
  "options": [
    {
      "label": "Yes",
      "value": "Y"
    },
    {
      "label": "No",
      "value": "N"
    }
  ],
  "group": "ACME Settings"
}
IRANUX_PARAM

MODIFY_ACME_RELOADCMD="${MODIFY_ACME_RELOADCMD:-N}"

: <<'IRANUX_PARAM'
{
  "name": "acme_reloadcmd_choice",
  "label": "ACME Reload Command Choice",
  "description": "Reload command option used only when Modify ACME Reload Command is Yes.",
  "type": "enum",
  "required": false,
  "default": "0",
  "options": [
    {
      "label": "Keep default reload command",
      "value": "0"
    },
    {
      "label": "Reload nginx and restart x-ui",
      "value": "1"
    },
    {
      "label": "Custom reload command",
      "value": "2"
    }
  ],
  "group": "ACME Settings"
}
IRANUX_PARAM

ACME_RELOADCMD_CHOICE="${ACME_RELOADCMD_CHOICE:-0}"

: <<'IRANUX_PARAM'
{
  "name": "custom_acme_reloadcmd",
  "label": "Custom ACME Reload Command",
  "description": "Custom acme.sh reload command. Used only when ACME Reload Command Choice is Custom.",
  "type": "string",
  "required": false,
  "example": "systemctl reload nginx ; systemctl restart x-ui",
  "group": "ACME Settings"
}
IRANUX_PARAM

CUSTOM_ACME_RELOADCMD="${CUSTOM_ACME_RELOADCMD:-}"

: <<'IRANUX_PARAM'
{
  "name": "set_certificate_for_panel",
  "label": "Set Certificate for Panel",
  "description": "Choose whether the issued domain certificate should be configured for the x-ui panel.",
  "type": "enum",
  "required": false,
  "default": "Y",
  "options": [
    {
      "label": "Yes",
      "value": "Y"
    },
    {
      "label": "No",
      "value": "N"
    }
  ],
  "group": "SSL Settings"
}
IRANUX_PARAM

SET_CERTIFICATE_FOR_PANEL="${SET_CERTIFICATE_FOR_PANEL:-Y}"

# ==============================================================================
# END IRANUX PARAMETERS
# ==============================================================================


red='\033[0;31m'
green='\033[0;32m'
blue='\033[0;34m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

xui_folder="${XUI_MAIN_FOLDER:=/usr/local/x-ui}"
xui_service="${XUI_SERVICE:=/etc/systemd/system}"

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Fatal error: ${plain} Please run this script with root privilege \n " && exit 1

# Check OS and set release variable
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
elif [[ -f /usr/lib/os-release ]]; then
    source /usr/lib/os-release
    release=$ID
else
    echo "Failed to check the system OS, please contact the author!" >&2
    exit 1
fi
echo "The OS release is: $release"

arch() {
    case "$(uname -m)" in
        x86_64 | x64 | amd64) echo 'amd64' ;;
        i*86 | x86) echo '386' ;;
        armv8* | armv8 | arm64 | aarch64) echo 'arm64' ;;
        armv7* | armv7 | arm) echo 'armv7' ;;
        armv6* | armv6) echo 'armv6' ;;
        armv5* | armv5) echo 'armv5' ;;
        s390x) echo 's390x' ;;
        *) echo -e "${green}Unsupported CPU architecture! ${plain}" && rm -f install.sh && exit 1 ;;
    esac
}

echo "Arch: $(arch)"

# Simple helpers
is_ipv4() {
    [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && return 0 || return 1
}
is_ipv6() {
    [[ "$1" =~ : ]] && return 0 || return 1
}
is_ip() {
    is_ipv4 "$1" || is_ipv6 "$1"
}
is_domain() {
    [[ "$1" =~ ^([A-Za-z0-9](-*[A-Za-z0-9])*\.)+(xn--[a-z0-9]{2,}|[A-Za-z]{2,})$ ]] && return 0 || return 1
}

# Port helpers
is_port_in_use() {
    local port="$1"
    if command -v ss > /dev/null 2>&1; then
        ss -ltn 2> /dev/null | awk -v p=":${port}$" '$4 ~ p {exit 0} END {exit 1}'
        return
    fi
    if command -v netstat > /dev/null 2>&1; then
        netstat -lnt 2> /dev/null | awk -v p=":${port} " '$4 ~ p {exit 0} END {exit 1}'
        return
    fi
    if command -v lsof > /dev/null 2>&1; then
        lsof -nP -iTCP:${port} -sTCP:LISTEN > /dev/null 2>&1 && return 0
    fi
    return 1
}

install_base() {
    case "${release}" in
        ubuntu | debian | armbian)
            apt-get update && apt-get install -y -q cron curl tar tzdata socat ca-certificates openssl
            ;;
        fedora | amzn | virtuozzo | rhel | almalinux | rocky | ol)
            dnf -y update && dnf install -y -q cronie curl tar tzdata socat ca-certificates openssl
            ;;
        centos)
            if [[ "${VERSION_ID}" =~ ^7 ]]; then
                yum -y update && yum install -y cronie curl tar tzdata socat ca-certificates openssl
            else
                dnf -y update && dnf install -y -q cronie curl tar tzdata socat ca-certificates openssl
            fi
            ;;
        arch | manjaro | parch)
            pacman -Syu && pacman -Syu --noconfirm cronie curl tar tzdata socat ca-certificates openssl
            ;;
        opensuse-tumbleweed | opensuse-leap)
            zypper refresh && zypper -q install -y cron curl tar timezone socat ca-certificates openssl
            ;;
        alpine)
            apk update && apk add dcron curl tar tzdata socat ca-certificates openssl
            ;;
        *)
            apt-get update && apt-get install -y -q cron curl tar tzdata socat ca-certificates openssl
            ;;
    esac
}

gen_random_string() {
    local length="$1"
    openssl rand -base64 $((length * 2)) \
        | tr -dc 'a-zA-Z0-9' \
        | head -c "$length"
}

install_postgres_local() {
    local pg_user="xui"
    local pg_db="xui"
    local pg_pass
    pg_pass=$(gen_random_string 24)

    case "${release}" in
        ubuntu | debian | armbian)
            apt-get update >&2 && apt-get install -y -q postgresql >&2 || return 1
            ;;
        fedora | amzn | virtuozzo | rhel | almalinux | rocky | ol)
            dnf install -y -q postgresql-server postgresql-contrib >&2 || return 1
            [[ -d /var/lib/pgsql/data && -f /var/lib/pgsql/data/PG_VERSION ]] || postgresql-setup --initdb >&2 || return 1
            ;;
        centos)
            if [[ "${VERSION_ID}" =~ ^7 ]]; then
                yum install -y postgresql-server postgresql-contrib >&2 || return 1
            else
                dnf install -y -q postgresql-server postgresql-contrib >&2 || return 1
            fi
            [[ -d /var/lib/pgsql/data && -f /var/lib/pgsql/data/PG_VERSION ]] || postgresql-setup --initdb >&2 || return 1
            ;;
        arch | manjaro | parch)
            pacman -Syu --noconfirm postgresql >&2 || return 1
            if [[ ! -f /var/lib/postgres/data/PG_VERSION ]]; then
                sudo -u postgres initdb -D /var/lib/postgres/data >&2 || return 1
            fi
            ;;
        opensuse-tumbleweed | opensuse-leap)
            zypper -q install -y postgresql-server postgresql-contrib >&2 || return 1
            if [[ ! -f /var/lib/pgsql/data/PG_VERSION ]]; then
                install -d -o postgres -g postgres -m 700 /var/lib/pgsql/data >&2 || return 1
                su - postgres -c "initdb -D /var/lib/pgsql/data" >&2 || return 1
            fi
            ;;
        alpine)
            apk add --no-cache postgresql postgresql-contrib >&2 || return 1
            if [[ ! -f /var/lib/postgresql/data/PG_VERSION ]]; then
                /etc/init.d/postgresql setup >&2 || return 1
            fi
            rc-update add postgresql default >&2 2> /dev/null || true
            rc-service postgresql start >&2 || return 1
            ;;
        *)
            echo -e "${red}Unsupported distro for automatic PostgreSQL install: ${release}${plain}" >&2
            return 1
            ;;
    esac

    if [[ "${release}" != "alpine" ]]; then
        systemctl enable --now postgresql >&2 || return 1
    fi

    # Wait briefly for the server to accept connections.
    local i
    for i in 1 2 3 4 5; do
        sudo -u postgres psql -tAc 'SELECT 1' > /dev/null 2>&1 && break
        sleep 1
    done

    # Idempotent role/db creation.
    sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${pg_user}'" 2> /dev/null \
        | grep -q 1 \
        || sudo -u postgres psql -c "CREATE USER ${pg_user} WITH PASSWORD '${pg_pass}';" >&2 || return 1

    sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${pg_db}'" 2> /dev/null \
        | grep -q 1 \
        || sudo -u postgres psql -c "CREATE DATABASE ${pg_db} OWNER ${pg_user};" >&2 || return 1

    sudo -u postgres psql -c "ALTER USER ${pg_user} WITH PASSWORD '${pg_pass}';" >&2 || return 1

    local pg_pass_enc
    pg_pass_enc=$(printf '%s' "${pg_pass}" | sed -e 's/%/%25/g' -e 's/:/%3A/g' -e 's/@/%40/g' -e 's|/|%2F|g' -e 's/?/%3F/g' -e 's/#/%23/g')
    echo "postgres://${pg_user}:${pg_pass_enc}@127.0.0.1:5432/${pg_db}?sslmode=disable"
    return 0
}

install_acme() {
    echo -e "${green}Installing acme.sh for SSL certificate management...${plain}"
    cd ~ || return 1
    curl -s https://get.acme.sh | sh > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "${red}Failed to install acme.sh${plain}"
        return 1
    else
        echo -e "${green}acme.sh installed successfully${plain}"
    fi
    return 0
}

setup_ssl_certificate() {
    local domain="$1"
    local server_ip="$2"
    local existing_port="$3"
    local existing_webBasePath="$4"

    echo -e "${green}Setting up SSL certificate...${plain}"

    # Check if acme.sh is installed
    if ! command -v ~/.acme.sh/acme.sh &> /dev/null; then
        install_acme
        if [ $? -ne 0 ]; then
            echo -e "${yellow}Failed to install acme.sh, skipping SSL setup${plain}"
            return 1
        fi
    fi

    # Create certificate directory
    local certPath="/root/cert/${domain}"
    mkdir -p "$certPath"

    # Issue certificate
    echo -e "${green}Issuing SSL certificate for ${domain}...${plain}"
    echo -e "${yellow}Note: Port 80 must be open and accessible from the internet${plain}"

    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt --force > /dev/null 2>&1
    ~/.acme.sh/acme.sh --issue -d ${domain} --listen-v6 --standalone --httpport 80 --force

    if [ $? -ne 0 ]; then
        echo -e "${yellow}Failed to issue certificate for ${domain}${plain}"
        echo -e "${yellow}Please ensure port 80 is open and try again later with: x-ui${plain}"
        rm -rf ~/.acme.sh/${domain} 2> /dev/null
        rm -rf "$certPath" 2> /dev/null
        return 1
    fi

    # Install certificate
    ~/.acme.sh/acme.sh --installcert -d ${domain} \
        --key-file /root/cert/${domain}/privkey.pem \
        --fullchain-file /root/cert/${domain}/fullchain.pem \
        --reloadcmd "systemctl restart x-ui" > /dev/null 2>&1

    if [ $? -ne 0 ]; then
        echo -e "${yellow}Failed to install certificate${plain}"
        return 1
    fi

    # Enable auto-renew
    ~/.acme.sh/acme.sh --upgrade --auto-upgrade > /dev/null 2>&1
    # Secure permissions: private key readable only by owner
    chmod 600 $certPath/privkey.pem 2> /dev/null
    chmod 644 $certPath/fullchain.pem 2> /dev/null

    # Set certificate for panel
    local webCertFile="/root/cert/${domain}/fullchain.pem"
    local webKeyFile="/root/cert/${domain}/privkey.pem"

    if [[ -f "$webCertFile" && -f "$webKeyFile" ]]; then
        ${xui_folder}/x-ui cert -webCert "$webCertFile" -webCertKey "$webKeyFile" > /dev/null 2>&1
        echo -e "${green}SSL certificate installed and configured successfully!${plain}"
        return 0
    else
        echo -e "${yellow}Certificate files not found${plain}"
        return 1
    fi
}

# Issue Let's Encrypt IP certificate with shortlived profile (~6 days validity)
# Requires acme.sh and port 80 open for HTTP-01 challenge
setup_ip_certificate() {
    local ipv4="$1"
    local ipv6="$2" # optional

    echo -e "${green}Setting up Let's Encrypt IP certificate (shortlived profile)...${plain}"
    echo -e "${yellow}Note: IP certificates are valid for ~6 days and will auto-renew.${plain}"
    echo -e "${yellow}Default listener is port 80. If you choose another port, ensure external port 80 forwards to it.${plain}"

    # Check for acme.sh
    if ! command -v ~/.acme.sh/acme.sh &> /dev/null; then
        install_acme
        if [ $? -ne 0 ]; then
            echo -e "${red}Failed to install acme.sh${plain}"
            return 1
        fi
    fi

    # Validate IP address
    if [[ -z "$ipv4" ]]; then
        echo -e "${red}IPv4 address is required${plain}"
        return 1
    fi

    if ! is_ipv4 "$ipv4"; then
        echo -e "${red}Invalid IPv4 address: $ipv4${plain}"
        return 1
    fi

    # Create certificate directory
    local certDir="/root/cert/ip"
    mkdir -p "$certDir"

    # Build domain arguments
    local domain_args="-d ${ipv4}"
    if [[ -n "$ipv6" ]] && is_ipv6 "$ipv6"; then
        domain_args="${domain_args} -d ${ipv6}"
        echo -e "${green}Including IPv6 address: ${ipv6}${plain}"
    fi

    # Set reload command for auto-renewal (add || true so it doesn't fail during first install)
    local reloadCmd="systemctl restart x-ui 2>/dev/null || rc-service x-ui restart 2>/dev/null || true"

    # Choose port for HTTP-01 listener (default 80) from Iranux parameter.
    local WebPort="${IP_CERT_HTTP_PORT:-80}"
    if ! [[ "${WebPort}" =~ ^[0-9]+$ ]] || ((WebPort < 1 || WebPort > 65535)); then
        echo -e "${red}Invalid IP certificate HTTP port provided. Falling back to 80.${plain}"
        WebPort=80
    fi
    echo -e "${green}Using port ${WebPort} for standalone validation.${plain}"
    if [[ "${WebPort}" -ne 80 ]]; then
        echo -e "${yellow}Reminder: Let's Encrypt still connects on port 80; forward external port 80 to ${WebPort}.${plain}"
    fi

    # Ensure chosen port is available without interactive prompts.
    if is_port_in_use "${WebPort}"; then
        echo -e "${yellow}Port ${WebPort} is in use.${plain}"
        local alt_port="${IP_CERT_ALT_HTTP_PORT:-}"
        alt_port="${alt_port// /}"
        if [[ -z "${alt_port}" ]]; then
            echo -e "${red}Port ${WebPort} is busy and no alternative port was provided.${plain}"
            return 1
        fi
        if ! [[ "${alt_port}" =~ ^[0-9]+$ ]] || ((alt_port < 1 || alt_port > 65535)); then
            echo -e "${red}Invalid alternative port provided.${plain}"
            return 1
        fi
        if is_port_in_use "${alt_port}"; then
            echo -e "${red}Alternative port ${alt_port} is also in use; cannot proceed.${plain}"
            return 1
        fi
        WebPort="${alt_port}"
        echo -e "${green}Alternative port ${WebPort} is free and ready for standalone validation.${plain}"
    else
        echo -e "${green}Port ${WebPort} is free and ready for standalone validation.${plain}"
    fi

    # Issue certificate with shortlived profile
    echo -e "${green}Issuing IP certificate for ${ipv4}...${plain}"
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt --force > /dev/null 2>&1

    ~/.acme.sh/acme.sh --issue \
        ${domain_args} \
        --standalone \
        --server letsencrypt \
        --certificate-profile shortlived \
        --days 6 \
        --httpport ${WebPort} \
        --force

    if [ $? -ne 0 ]; then
        echo -e "${red}Failed to issue IP certificate${plain}"
        echo -e "${yellow}Please ensure port ${WebPort} is reachable (or forwarded from external port 80)${plain}"
        # Cleanup acme.sh data for both IPv4 and IPv6 if specified
        rm -rf ~/.acme.sh/${ipv4} 2> /dev/null
        [[ -n "$ipv6" ]] && rm -rf ~/.acme.sh/${ipv6} 2> /dev/null
        rm -rf ${certDir} 2> /dev/null
        return 1
    fi

    echo -e "${green}Certificate issued successfully, installing...${plain}"

    # Install certificate
    # Note: acme.sh may report "Reload error" and exit non-zero if reloadcmd fails,
    # but the cert files are still installed. We check for files instead of exit code.
    ~/.acme.sh/acme.sh --installcert -d ${ipv4} \
        --key-file "${certDir}/privkey.pem" \
        --fullchain-file "${certDir}/fullchain.pem" \
        --reloadcmd "${reloadCmd}" 2>&1 || true

    # Verify certificate files exist (don't rely on exit code - reloadcmd failure causes non-zero)
    if [[ ! -f "${certDir}/fullchain.pem" || ! -f "${certDir}/privkey.pem" ]]; then
        echo -e "${red}Certificate files not found after installation${plain}"
        # Cleanup acme.sh data for both IPv4 and IPv6 if specified
        rm -rf ~/.acme.sh/${ipv4} 2> /dev/null
        [[ -n "$ipv6" ]] && rm -rf ~/.acme.sh/${ipv6} 2> /dev/null
        rm -rf ${certDir} 2> /dev/null
        return 1
    fi

    echo -e "${green}Certificate files installed successfully${plain}"

    # Enable auto-upgrade for acme.sh (ensures cron job runs)
    ~/.acme.sh/acme.sh --upgrade --auto-upgrade > /dev/null 2>&1

    # Secure permissions: private key readable only by owner
    chmod 600 ${certDir}/privkey.pem 2> /dev/null
    chmod 644 ${certDir}/fullchain.pem 2> /dev/null

    # Configure panel to use the certificate
    echo -e "${green}Setting certificate paths for the panel...${plain}"
    ${xui_folder}/x-ui cert -webCert "${certDir}/fullchain.pem" -webCertKey "${certDir}/privkey.pem"

    if [ $? -ne 0 ]; then
        echo -e "${yellow}Warning: Could not set certificate paths automatically${plain}"
        echo -e "${yellow}Certificate files are at:${plain}"
        echo -e "  Cert: ${certDir}/fullchain.pem"
        echo -e "  Key:  ${certDir}/privkey.pem"
    else
        echo -e "${green}Certificate paths configured successfully${plain}"
    fi

    echo -e "${green}IP certificate installed and configured successfully!${plain}"
    echo -e "${green}Certificate valid for ~6 days, auto-renews via acme.sh cron job.${plain}"
    echo -e "${yellow}acme.sh will automatically renew and reload x-ui before expiry.${plain}"
    return 0
}

# Comprehensive manual SSL certificate issuance via acme.sh
ssl_cert_issue() {
    local existing_webBasePath=$(${xui_folder}/x-ui setting -show true | grep 'webBasePath:' | awk -F': ' '{print $2}' | tr -d '[:space:]' | sed 's#^/##')
    local existing_port=$(${xui_folder}/x-ui setting -show true | grep 'port:' | awk -F': ' '{print $2}' | tr -d '[:space:]')

    # check for acme.sh first
    if ! command -v ~/.acme.sh/acme.sh &> /dev/null; then
        echo "acme.sh could not be found. Installing now..."
        cd ~ || return 1
        curl -s https://get.acme.sh | sh
        if [ $? -ne 0 ]; then
            echo -e "${red}Failed to install acme.sh${plain}"
            return 1
        else
            echo -e "${green}acme.sh installed successfully${plain}"
        fi
    fi

    # Use Iranux-provided domain instead of interactive prompt.
    local domain="${SSL_DOMAIN:-}"
    domain="${domain// /}" # Trim whitespace

    if [[ -z "$domain" ]]; then
        echo -e "${red}Domain name cannot be empty. Provide ssl_domain.${plain}"
        return 1
    fi

    if ! is_domain "$domain"; then
        echo -e "${red}Invalid domain format: ${domain}. Provide a valid ssl_domain.${plain}"
        return 1
    fi

    echo -e "${green}Your domain is: ${domain}, checking it...${plain}"
    SSL_ISSUED_DOMAIN="${domain}"

    # detect existing certificate and reuse it if present
    local cert_exists=0
    if ~/.acme.sh/acme.sh --list 2> /dev/null | awk '{print $1}' | grep -Fxq "${domain}"; then
        cert_exists=1
        local certInfo=$(~/.acme.sh/acme.sh --list 2> /dev/null | grep -F "${domain}")
        echo -e "${yellow}Existing certificate found for ${domain}, will reuse it.${plain}"
        [[ -n "${certInfo}" ]] && echo "$certInfo"
    else
        echo -e "${green}Your domain is ready for issuing certificates now...${plain}"
    fi

    # create a directory for the certificate
    certPath="/root/cert/${domain}"
    if [ ! -d "$certPath" ]; then
        mkdir -p "$certPath"
    else
        rm -rf "$certPath"
        mkdir -p "$certPath"
    fi

    # get the port number for the standalone server from Iranux parameter
    local WebPort="${SSL_HTTP_PORT:-80}"
    if ! [[ "${WebPort}" =~ ^[0-9]+$ ]] || [[ ${WebPort} -gt 65535 || ${WebPort} -lt 1 ]]; then
        echo -e "${yellow}Your SSL HTTP port ${WebPort} is invalid, will use default port 80.${plain}"
        WebPort=80
    fi
    echo -e "${green}Will use port: ${WebPort} to issue certificates. Please make sure this port is open.${plain}"

    # Stop panel temporarily
    echo -e "${yellow}Stopping panel temporarily...${plain}"
    systemctl stop x-ui 2> /dev/null || rc-service x-ui stop 2> /dev/null

    if [[ ${cert_exists} -eq 0 ]]; then
        # issue the certificate
        ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt --force
        ~/.acme.sh/acme.sh --issue -d ${domain} --listen-v6 --standalone --httpport ${WebPort} --force
        if [ $? -ne 0 ]; then
            echo -e "${red}Issuing certificate failed, please check logs.${plain}"
            rm -rf ~/.acme.sh/${domain}
            systemctl start x-ui 2> /dev/null || rc-service x-ui start 2> /dev/null
            return 1
        else
            echo -e "${green}Issuing certificate succeeded, installing certificates...${plain}"
        fi
    else
        echo -e "${green}Using existing certificate, installing certificates...${plain}"
    fi

    # Setup reload command from Iranux parameters
    reloadCmd="systemctl restart x-ui || rc-service x-ui restart"
    echo -e "${green}Default --reloadcmd for ACME is: ${yellow}systemctl restart x-ui || rc-service x-ui restart${plain}"
    echo -e "${green}This command will run on every certificate issue and renew.${plain}"
    local setReloadcmd="${MODIFY_ACME_RELOADCMD:-N}"
    if [[ "$setReloadcmd" == "y" || "$setReloadcmd" == "Y" ]]; then
        local choice="${ACME_RELOADCMD_CHOICE:-0}"
        case "$choice" in
            1)
                echo -e "${green}Reloadcmd is: systemctl reload nginx ; systemctl restart x-ui${plain}"
                reloadCmd="systemctl reload nginx ; systemctl restart x-ui"
                ;;
            2)
                if [[ -z "${CUSTOM_ACME_RELOADCMD:-}" ]]; then
                    echo -e "${red}Custom reload command selected but custom_acme_reloadcmd is empty.${plain}"
                    return 1
                fi
                reloadCmd="${CUSTOM_ACME_RELOADCMD}"
                echo -e "${green}Reloadcmd is: ${reloadCmd}${plain}"
                ;;
            *)
                echo -e "${green}Keeping default reloadcmd${plain}"
                ;;
        esac
    fi

    # install the certificate
    local installOutput=""
    installOutput=$(~/.acme.sh/acme.sh --installcert -d ${domain} \
        --key-file /root/cert/${domain}/privkey.pem \
        --fullchain-file /root/cert/${domain}/fullchain.pem --reloadcmd "${reloadCmd}" 2>&1)
    local installRc=$?
    echo "${installOutput}"

    local installWroteFiles=0
    if echo "${installOutput}" | grep -q "Installing key to:" && echo "${installOutput}" | grep -q "Installing full chain to:"; then
        installWroteFiles=1
    fi

    if [[ -f "/root/cert/${domain}/privkey.pem" && -f "/root/cert/${domain}/fullchain.pem" && (${installRc} -eq 0 || ${installWroteFiles} -eq 1) ]]; then
        echo -e "${green}Installing certificate succeeded, enabling auto renew...${plain}"
    else
        echo -e "${red}Installing certificate failed, exiting.${plain}"
        if [[ ${cert_exists} -eq 0 ]]; then
            rm -rf ~/.acme.sh/${domain}
        fi
        systemctl start x-ui 2> /dev/null || rc-service x-ui start 2> /dev/null
        return 1
    fi

    # enable auto-renew
    ~/.acme.sh/acme.sh --upgrade --auto-upgrade
    if [ $? -ne 0 ]; then
        echo -e "${yellow}Auto renew setup had issues, certificate details:${plain}"
        ls -lah /root/cert/${domain}/
        # Secure permissions: private key readable only by owner
        chmod 600 $certPath/privkey.pem 2> /dev/null
        chmod 644 $certPath/fullchain.pem 2> /dev/null
    else
        echo -e "${green}Auto renew succeeded, certificate details:${plain}"
        ls -lah /root/cert/${domain}/
        # Secure permissions: private key readable only by owner
        chmod 600 $certPath/privkey.pem 2> /dev/null
        chmod 644 $certPath/fullchain.pem 2> /dev/null
    fi

    # start panel
    systemctl start x-ui 2> /dev/null || rc-service x-ui start 2> /dev/null

    # Set panel certificate based on Iranux parameter
    local setPanel="${SET_CERTIFICATE_FOR_PANEL:-Y}"
    if [[ "$setPanel" == "y" || "$setPanel" == "Y" ]]; then
        local webCertFile="/root/cert/${domain}/fullchain.pem"
        local webKeyFile="/root/cert/${domain}/privkey.pem"

        if [[ -f "$webCertFile" && -f "$webKeyFile" ]]; then
            ${xui_folder}/x-ui cert -webCert "$webCertFile" -webCertKey "$webKeyFile"
            echo -e "${green}Certificate paths set for the panel${plain}"
            echo -e "${green}Certificate File: $webCertFile${plain}"
            echo -e "${green}Private Key File: $webKeyFile${plain}"
            echo ""
            echo -e "${green}Access URL: https://${domain}:${existing_port}/${existing_webBasePath}${plain}"
            echo -e "${yellow}Panel will restart to apply SSL certificate...${plain}"
            systemctl restart x-ui 2> /dev/null || rc-service x-ui restart 2> /dev/null
        else
            echo -e "${red}Error: Certificate or private key file not found for domain: $domain.${plain}"
        fi
    else
        echo -e "${yellow}Skipping panel path setting.${plain}"
    fi

    return 0
}

# Reusable interactive SSL setup (domain or IP)
# Sets global `SSL_HOST` to the chosen domain/IP for Access URL usage
prompt_and_setup_ssl() {
    local panel_port="$1"
    local web_base_path="$2"
    local server_ip="$3"

    local ssl_choice=""
    SSL_SCHEME="https"

    echo -e "${yellow}Choose SSL certificate setup method:${plain}"
    echo -e "${green}1.${plain} Let's Encrypt for Domain (90-day validity, auto-renews)"
    echo -e "${green}2.${plain} Let's Encrypt for IP Address (6-day validity, auto-renews)"
    echo -e "${green}3.${plain} Custom SSL Certificate (Path to existing files)"
    echo -e "${green}4.${plain} Skip SSL (advanced — behind reverse proxy / SSH tunnel only)"
    echo -e "${blue}Note:${plain} Options 1 & 2 require port 80 open. Option 3 requires manual paths."
    echo -e "${blue}Note:${plain} Option 4 serves the panel over plain HTTP — only safe behind nginx/Caddy or an SSH tunnel."
    ssl_choice="${SSL_SETUP_METHOD:-2}"
    ssl_choice="${ssl_choice// /}" # Trim whitespace

    # Default to 2 (IP cert) if input is empty or invalid (not 1, 3 or 4)
    if [[ "$ssl_choice" != "1" && "$ssl_choice" != "3" && "$ssl_choice" != "4" ]]; then
        ssl_choice="2"
    fi

    case "$ssl_choice" in
        1)
            # User chose Let's Encrypt domain option
            echo -e "${green}Using Let's Encrypt for domain certificate...${plain}"
            if ssl_cert_issue; then
                local cert_domain="${SSL_ISSUED_DOMAIN}"
                if [[ -z "${cert_domain}" ]]; then
                    cert_domain=$(~/.acme.sh/acme.sh --list 2> /dev/null | tail -1 | awk '{print $1}')
                fi

                if [[ -n "${cert_domain}" ]]; then
                    SSL_HOST="${cert_domain}"
                    echo -e "${green}✓ SSL certificate configured successfully with domain: ${cert_domain}${plain}"
                else
                    echo -e "${yellow}SSL setup may have completed, but domain extraction failed${plain}"
                    SSL_HOST="${server_ip}"
                fi
            else
                echo -e "${red}SSL certificate setup failed for domain mode.${plain}"
                SSL_HOST="${server_ip}"
            fi
            ;;
        2)
            # User chose Let's Encrypt IP certificate option
            echo -e "${green}Using Let's Encrypt for IP certificate (shortlived profile)...${plain}"

            # Optional IPv6 address from Iranux parameter
            local ipv6_addr="${SSL_IPV6_ADDRESS:-}"
            ipv6_addr="${ipv6_addr// /}" # Trim whitespace

            # Stop panel if running (port 80 needed)
            if [[ $release == "alpine" ]]; then
                rc-service x-ui stop > /dev/null 2>&1
            else
                systemctl stop x-ui > /dev/null 2>&1
            fi

            setup_ip_certificate "${server_ip}" "${ipv6_addr}"
            if [ $? -eq 0 ]; then
                SSL_HOST="${server_ip}"
                echo -e "${green}✓ Let's Encrypt IP certificate configured successfully${plain}"
            else
                echo -e "${red}✗ IP certificate setup failed. Please check port 80 is open.${plain}"
                SSL_HOST="${server_ip}"
            fi
            ;;
        3)
            # User chose Custom Paths (User Provided) option
            echo -e "${green}Using custom existing certificate...${plain}"
            local custom_cert=""
            local custom_key=""
            local custom_domain=""

            # 3.1 Domain for Panel URL from Iranux parameter
            custom_domain="${CUSTOM_SSL_DOMAIN:-}"
            custom_domain="${custom_domain// /}" # Remove spaces

            # 3.2 Certificate Path from Iranux parameter
            custom_cert="${CUSTOM_CERT_PATH:-}"
            custom_cert=$(echo "$custom_cert" | tr -d '"' | tr -d "'")

            if [[ ! -f "$custom_cert" ]]; then
                echo -e "${red}Error: Certificate file does not exist. Provide custom_cert_path.${plain}"
                return 1
            elif [[ ! -r "$custom_cert" ]]; then
                echo -e "${red}Error: Certificate file exists but is not readable.${plain}"
                return 1
            elif [[ ! -s "$custom_cert" ]]; then
                echo -e "${red}Error: Certificate file is empty.${plain}"
                return 1
            fi

            # 3.3 Private Key Path from Iranux parameter
            custom_key="${CUSTOM_KEY_PATH:-}"
            custom_key=$(echo "$custom_key" | tr -d '"' | tr -d "'")

            if [[ ! -f "$custom_key" ]]; then
                echo -e "${red}Error: Private key file does not exist. Provide custom_key_path.${plain}"
                return 1
            elif [[ ! -r "$custom_key" ]]; then
                echo -e "${red}Error: Private key file exists but is not readable.${plain}"
                return 1
            elif [[ ! -s "$custom_key" ]]; then
                echo -e "${red}Error: Private key file is empty.${plain}"
                return 1
            fi

            # 3.4 Apply Settings via x-ui binary
            ${xui_folder}/x-ui cert -webCert "$custom_cert" -webCertKey "$custom_key" > /dev/null 2>&1

            # Set SSL_HOST for composing Panel URL
            if [[ -n "$custom_domain" ]]; then
                SSL_HOST="$custom_domain"
            else
                SSL_HOST="${server_ip}"
            fi

            echo -e "${green}✓ Custom certificate paths applied.${plain}"
            echo -e "${yellow}Note: You are responsible for renewing these files externally.${plain}"

            systemctl restart x-ui > /dev/null 2>&1 || rc-service x-ui restart > /dev/null 2>&1
            ;;
        4)
            echo ""
            echo -e "${red}⚠ Panel will be installed WITHOUT SSL/TLS.${plain}"
            echo -e "${yellow}Login credentials and cookies will travel as plain HTTP.${plain}"
            echo -e "${yellow}Only safe when:${plain}"
            echo -e "${yellow}  • A reverse proxy (nginx, Caddy, Traefik) terminates TLS for you, or${plain}"
            echo -e "${yellow}  • You access the panel exclusively via SSH tunnel${plain}"
            echo ""

            SSL_SCHEME="http"
            SSL_HOST="${server_ip}"

            local bind_local="${BIND_PANEL_LOCALHOST:-N}"
            if [[ "$bind_local" == "y" || "$bind_local" == "Y" ]]; then
                ${xui_folder}/x-ui setting -listenIP "127.0.0.1" > /dev/null 2>&1
                SSL_HOST="127.0.0.1"
                echo -e "${green}✓ Panel bound to 127.0.0.1 only. It is now unreachable from the public internet.${plain}"
                echo ""
                echo -e "${green}SSH Port Forwarding — open the panel from your local machine via:${plain}"
                echo -e "  Standard SSH command:"
                echo -e "  ${yellow}ssh -L 2222:127.0.0.1:${panel_port} root@${server_ip}${plain}"
                echo -e "  If using an SSH key:"
                echo -e "  ${yellow}ssh -i <sshkeypath> -L 2222:127.0.0.1:${panel_port} root@${server_ip}${plain}"
                echo -e "  Then open in your browser:"
                echo -e "  ${yellow}http://localhost:2222/${web_base_path}${plain}"
                echo ""
                echo -e "${yellow}Alternative: point a reverse proxy (nginx/Caddy) at 127.0.0.1:${panel_port} and let it terminate TLS.${plain}"
            else
                echo -e "${yellow}Panel will listen on all interfaces over plain HTTP. Make sure something else is terminating TLS in front of it.${plain}"
            fi

            systemctl restart x-ui > /dev/null 2>&1 || rc-service x-ui restart > /dev/null 2>&1
            echo -e "${green}✓ SSL setup skipped.${plain}"
            ;;
        *)
            echo -e "${red}Invalid option. Skipping SSL setup.${plain}"
            SSL_HOST="${server_ip}"
            ;;
    esac
}

config_after_install() {
    local existing_hasDefaultCredential=$(${xui_folder}/x-ui setting -show true | grep -Eo 'hasDefaultCredential: .+' | awk '{print $2}')
    local existing_webBasePath=$(${xui_folder}/x-ui setting -show true | grep -Eo 'webBasePath: .+' | awk '{print $2}' | sed 's#^/##')
    local existing_port=$(${xui_folder}/x-ui setting -show true | grep -Eo 'port: .+' | awk '{print $2}')
    # Properly detect empty cert by checking if cert: line exists and has content after it
    local existing_cert=$(${xui_folder}/x-ui setting -getCert true | grep 'cert:' | awk -F': ' '{print $2}' | tr -d '[:space:]')
    local URL_lists=(
        "https://api4.ipify.org"
        "https://ipv4.icanhazip.com"
        "https://v4.api.ipinfo.io/ip"
        "https://ipv4.myexternalip.com/raw"
        "https://4.ident.me"
        "https://check-host.net/ip"
    )
    local server_ip=""
    for ip_address in "${URL_lists[@]}"; do
        local response=$(curl -s -w "\n%{http_code}" --max-time 3 "${ip_address}" 2> /dev/null)
        local http_code=$(echo "$response" | tail -n1)
        local ip_result=$(echo "$response" | head -n-1 | tr -d '[:space:]"')
        if [[ "${http_code}" == "200" && "${ip_result}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            server_ip="${ip_result}"
            break
        fi
    done

    if [[ -z "$server_ip" ]]; then
        echo -e "${yellow}Could not auto-detect server IP from any provider.${plain}"
        server_ip="${SERVER_IPV4:-}"
        server_ip="${server_ip// /}"
        if [[ -z "$server_ip" ]]; then
            echo -e "${red}Server public IPv4 could not be auto-detected. Provide server_ipv4.${plain}"
            exit 1
        fi
        if [[ ! "$server_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo -e "${red}Invalid server_ipv4 provided.${plain}"
            exit 1
        fi
    fi

    if [[ ${#existing_webBasePath} -lt 4 ]]; then
        if [[ "$existing_hasDefaultCredential" == "true" ]]; then
            local config_webBasePath=$(gen_random_string 18)
            local config_username=$(gen_random_string 10)
            local config_password=$(gen_random_string 10)

            local db_label="SQLite (/etc/x-ui/x-ui.db)"
            echo ""
            echo -e "${green}═══════════════════════════════════════════${plain}"
            echo -e "${green}     Database Selection                    ${plain}"
            echo -e "${green}═══════════════════════════════════════════${plain}"
            echo -e "  1) SQLite     (default — recommended for < 1000 clients)"
            echo -e "  2) PostgreSQL (recommended for high client counts / many nodes)"
            db_choice="${DATABASE_TYPE:-1}"
            if [[ "$db_choice" == "2" ]]; then
                local xui_env_file
                case "${release}" in
                    ubuntu | debian | armbian)
                        xui_env_file="/etc/default/x-ui"
                        ;;
                    arch | manjaro | parch | alpine)
                        xui_env_file="/etc/conf.d/x-ui"
                        ;;
                    *)
                        xui_env_file="/etc/sysconfig/x-ui"
                        ;;
                esac

                local xui_dsn=""
                local pg_mode=""
                while [[ -z "$xui_dsn" ]]; do
                    echo ""
                    echo -e "  1) Install PostgreSQL locally and create a dedicated user/db (recommended)"
                    echo -e "  2) Use an existing PostgreSQL server (enter DSN)"
                    pg_mode="${POSTGRES_MODE:-1}"
                    if [[ "$pg_mode" == "2" ]]; then
                        xui_dsn="${POSTGRES_DSN:-}"
                        xui_dsn="${xui_dsn// /}"
                        if [[ -z "$xui_dsn" ]]; then
                            echo -e "${red}External PostgreSQL mode selected but postgres_dsn is empty.${plain}"
                            exit 1
                        fi
                        db_label="PostgreSQL (external)"
                    else
                        echo -e "${yellow}Installing PostgreSQL — this may take a moment...${plain}"
                        if xui_dsn=$(install_postgres_local); then
                            db_label="PostgreSQL (xui@127.0.0.1:5432/xui)"
                        else
                            echo ""
                            echo -e "${red}PostgreSQL installation failed.${plain}"
                            echo -e "  1) Retry local install"
                            echo -e "  2) Enter an external DSN instead"
                            echo -e "  3) Abort install"
                            echo -e "  4) Fall back to SQLite"
                            pg_fail="${POSTGRES_FAILURE_ACTION:-4}"
                            case "$pg_fail" in
                                2) pg_mode="2" ;;
                                3) echo -e "${red}Install aborted.${plain}"; exit 1 ;;
                                4) db_choice="1"; xui_dsn=""; break ;;
                                *) xui_dsn="" ;;
                            esac
                        fi
                    fi
                done
                if [[ -n "$xui_dsn" ]]; then
                    install -d -m 755 "$(dirname "$xui_env_file")"
                    umask 077
                    cat > "$xui_env_file" << EOF
XUI_DB_TYPE=postgres
XUI_DB_DSN=${xui_dsn}
EOF
                    chmod 600 "$xui_env_file"
                    umask 022
                    export XUI_DB_TYPE=postgres
                    export XUI_DB_DSN="${xui_dsn}"
                fi
            fi

            config_confirm="${CUSTOMIZE_PANEL_PORT:-N}"
            if [[ "${config_confirm}" == "y" || "${config_confirm}" == "Y" ]]; then
                config_port="${PANEL_PORT:-}"
                if [[ -z "${config_port}" ]]; then
                    echo -e "${red}Panel port customization selected but panel_port is empty.${plain}"
                    exit 1
                fi
                if ! [[ "${config_port}" =~ ^[0-9]+$ ]] || ((config_port < 1 || config_port > 65535)); then
                    echo -e "${red}Invalid panel_port provided.${plain}"
                    exit 1
                fi
                echo -e "${yellow}Your Panel Port is: ${config_port}${plain}"
            else
                local config_port=$(shuf -i 1024-62000 -n 1)
                echo -e "${yellow}Generated random port: ${config_port}${plain}"
            fi

            ${xui_folder}/x-ui setting -username "${config_username}" -password "${config_password}" -port "${config_port}" -webBasePath "${config_webBasePath}"

            echo ""
            echo -e "${green}═══════════════════════════════════════════${plain}"
            echo -e "${green}     SSL Certificate Setup (RECOMMENDED)   ${plain}"
            echo -e "${green}═══════════════════════════════════════════${plain}"
            echo -e "${yellow}SSL is strongly recommended. Skip only if a reverse proxy${plain}"
            echo -e "${yellow}or SSH tunnel handles TLS for you.${plain}"
            echo -e "${yellow}Let's Encrypt now supports both domains and IP addresses!${plain}"
            echo ""

            prompt_and_setup_ssl "${config_port}" "${config_webBasePath}" "${server_ip}"

            # Retrieve the API token for display
            local config_apiToken=$(${xui_folder}/x-ui setting -getApiToken true | grep -Eo 'apiToken: .+' | awk '{print $2}')

            # Display final credentials and access information
            echo ""
            echo -e "${green}═══════════════════════════════════════════${plain}"
            echo -e "${green}     Panel Installation Complete!         ${plain}"
            echo -e "${green}═══════════════════════════════════════════${plain}"
            echo -e "${green}Username:    ${config_username}${plain}"
            echo -e "${green}Password:    ${config_password}${plain}"
            echo -e "${green}Port:        ${config_port}${plain}"
            echo -e "${green}WebBasePath: ${config_webBasePath}${plain}"
            echo -e "${green}Database:    ${db_label}${plain}"
            echo -e "${green}Access URL:  ${SSL_SCHEME}://${SSL_HOST}:${config_port}/${config_webBasePath}${plain}"
            echo -e "${green}API Token:   ${config_apiToken}${plain}"
            echo -e "${green}═══════════════════════════════════════════${plain}"
            echo -e "${yellow}⚠ IMPORTANT: Save these credentials securely!${plain}"
            if [[ "$SSL_SCHEME" == "https" ]]; then
                echo -e "${yellow}⚠ SSL Certificate: Enabled and configured${plain}"
            else
                echo -e "${yellow}⚠ SSL Certificate: Skipped — panel is HTTP-only. Use a reverse proxy or SSH tunnel.${plain}"
            fi
        else
            local config_webBasePath=$(gen_random_string 18)
            echo -e "${yellow}WebBasePath is missing or too short. Generating a new one...${plain}"
            ${xui_folder}/x-ui setting -webBasePath "${config_webBasePath}"
            echo -e "${green}New WebBasePath: ${config_webBasePath}${plain}"

            # If the panel is already installed but no certificate is configured, prompt for SSL now
            if [[ -z "${existing_cert}" ]]; then
                echo ""
                echo -e "${green}═══════════════════════════════════════════${plain}"
                echo -e "${green}     SSL Certificate Setup (RECOMMENDED)   ${plain}"
                echo -e "${green}═══════════════════════════════════════════${plain}"
                echo -e "${yellow}Let's Encrypt now supports both domains and IP addresses!${plain}"
                echo ""
                prompt_and_setup_ssl "${existing_port}" "${config_webBasePath}" "${server_ip}"
                echo -e "${green}Access URL:  ${SSL_SCHEME}://${SSL_HOST}:${existing_port}/${config_webBasePath}${plain}"
            else
                # If a cert already exists, just show the access URL
                echo -e "${green}Access URL: https://${server_ip}:${existing_port}/${config_webBasePath}${plain}"
            fi
        fi
    else
        if [[ "$existing_hasDefaultCredential" == "true" ]]; then
            local config_username=$(gen_random_string 10)
            local config_password=$(gen_random_string 10)

            echo -e "${yellow}Default credentials detected. Security update required...${plain}"
            ${xui_folder}/x-ui setting -username "${config_username}" -password "${config_password}"
            echo -e "Generated new random login credentials:"
            echo -e "###############################################"
            echo -e "${green}Username: ${config_username}${plain}"
            echo -e "${green}Password: ${config_password}${plain}"
            echo -e "###############################################"
        else
            echo -e "${green}Username, Password, and WebBasePath are properly set.${plain}"
        fi

        # Existing install: if no cert configured, prompt user for SSL setup
        # Properly detect empty cert by checking if cert: line exists and has content after it
        existing_cert=$(${xui_folder}/x-ui setting -getCert true | grep 'cert:' | awk -F': ' '{print $2}' | tr -d '[:space:]')
        if [[ -z "$existing_cert" ]]; then
            echo ""
            echo -e "${green}═══════════════════════════════════════════${plain}"
            echo -e "${green}     SSL Certificate Setup (RECOMMENDED)   ${plain}"
            echo -e "${green}═══════════════════════════════════════════${plain}"
            echo -e "${yellow}Let's Encrypt now supports both domains and IP addresses!${plain}"
            echo ""
            prompt_and_setup_ssl "${existing_port}" "${existing_webBasePath}" "${server_ip}"
            echo -e "${green}Access URL:  ${SSL_SCHEME}://${SSL_HOST}:${existing_port}/${existing_webBasePath}${plain}"
        else
            echo -e "${green}SSL certificate already configured. No action needed.${plain}"
        fi
    fi

    ${xui_folder}/x-ui migrate
}

install_x-ui() {
    cd ${xui_folder%/x-ui}/

    # Download resources
    if [ $# == 0 ]; then
        tag_version=$(curl -Ls "https://api.github.com/repos/MHSanaei/3x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$tag_version" ]]; then
            echo -e "${yellow}Trying to fetch version with IPv4...${plain}"
            tag_version=$(curl -4 -Ls "https://api.github.com/repos/MHSanaei/3x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
            if [[ ! -n "$tag_version" ]]; then
                echo -e "${red}Failed to fetch x-ui version, it may be due to GitHub API restrictions, please try it later${plain}"
                exit 1
            fi
        fi
        echo -e "Got x-ui latest version: ${tag_version}, beginning the installation..."
        curl -4fLRo ${xui_folder}-linux-$(arch).tar.gz https://github.com/MHSanaei/3x-ui/releases/download/${tag_version}/x-ui-linux-$(arch).tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Downloading x-ui failed, please be sure that your server can access GitHub ${plain}"
            exit 1
        fi
    else
        tag_version=$1
        tag_version_numeric=${tag_version#v}
        min_version="2.3.5"

        if [[ "$(printf '%s\n' "$min_version" "$tag_version_numeric" | sort -V | head -n1)" != "$min_version" ]]; then
            echo -e "${red}Please use a newer version (at least v2.3.5). Exiting installation.${plain}"
            exit 1
        fi

        url="https://github.com/MHSanaei/3x-ui/releases/download/${tag_version}/x-ui-linux-$(arch).tar.gz"
        echo -e "Beginning to install x-ui $1"
        curl -4fLRo ${xui_folder}-linux-$(arch).tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Download x-ui $1 failed, please check if the version exists ${plain}"
            exit 1
        fi
    fi
    curl -4fLRo /usr/bin/x-ui-temp https://raw.githubusercontent.com/MHSanaei/3x-ui/main/x-ui.sh
    if [[ $? -ne 0 ]]; then
        echo -e "${red}Failed to download x-ui.sh${plain}"
        exit 1
    fi

    # Stop x-ui service and remove old resources
    if [[ -e ${xui_folder}/ ]]; then
        if [[ $release == "alpine" ]]; then
            rc-service x-ui stop
        else
            systemctl stop x-ui
        fi
        rm ${xui_folder}/ -rf
    fi

    # Extract resources and set permissions
    tar zxvf x-ui-linux-$(arch).tar.gz
    rm x-ui-linux-$(arch).tar.gz -f

    cd x-ui
    chmod +x x-ui
    chmod +x x-ui.sh

    # Check the system's architecture and rename the file accordingly
    if [[ $(arch) == "armv5" || $(arch) == "armv6" || $(arch) == "armv7" ]]; then
        mv bin/xray-linux-$(arch) bin/xray-linux-arm
        chmod +x bin/xray-linux-arm
    fi
    chmod +x x-ui bin/xray-linux-$(arch)

    # Update x-ui cli and se set permission
    mv -f /usr/bin/x-ui-temp /usr/bin/x-ui
    chmod +x /usr/bin/x-ui
    mkdir -p /var/log/x-ui
    config_after_install

    # Etckeeper compatibility
    if [ -d "/etc/.git" ]; then
        if [ -f "/etc/.gitignore" ]; then
            if ! grep -q "x-ui/x-ui.db" "/etc/.gitignore"; then
                echo "" >> "/etc/.gitignore"
                echo "x-ui/x-ui.db" >> "/etc/.gitignore"
                echo -e "${green}Added x-ui.db to /etc/.gitignore for etckeeper${plain}"
            fi
        else
            echo "x-ui/x-ui.db" > "/etc/.gitignore"
            echo -e "${green}Created /etc/.gitignore and added x-ui.db for etckeeper${plain}"
        fi
    fi

    if [[ $release == "alpine" ]]; then
        curl -4fLRo /etc/init.d/x-ui https://raw.githubusercontent.com/MHSanaei/3x-ui/main/x-ui.rc
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Failed to download x-ui.rc${plain}"
            exit 1
        fi
        chmod +x /etc/init.d/x-ui
        rc-update add x-ui
        rc-service x-ui start
    else
        # Install systemd service file
        service_installed=false

        if [ -f "x-ui.service" ]; then
            echo -e "${green}Found x-ui.service in extracted files, installing...${plain}"
            cp -f x-ui.service ${xui_service}/ > /dev/null 2>&1
            if [[ $? -eq 0 ]]; then
                service_installed=true
            fi
        fi

        if [ "$service_installed" = false ]; then
            case "${release}" in
                ubuntu | debian | armbian)
                    if [ -f "x-ui.service.debian" ]; then
                        echo -e "${green}Found x-ui.service.debian in extracted files, installing...${plain}"
                        cp -f x-ui.service.debian ${xui_service}/x-ui.service > /dev/null 2>&1
                        if [[ $? -eq 0 ]]; then
                            service_installed=true
                        fi
                    fi
                    ;;
                arch | manjaro | parch)
                    if [ -f "x-ui.service.arch" ]; then
                        echo -e "${green}Found x-ui.service.arch in extracted files, installing...${plain}"
                        cp -f x-ui.service.arch ${xui_service}/x-ui.service > /dev/null 2>&1
                        if [[ $? -eq 0 ]]; then
                            service_installed=true
                        fi
                    fi
                    ;;
                *)
                    if [ -f "x-ui.service.rhel" ]; then
                        echo -e "${green}Found x-ui.service.rhel in extracted files, installing...${plain}"
                        cp -f x-ui.service.rhel ${xui_service}/x-ui.service > /dev/null 2>&1
                        if [[ $? -eq 0 ]]; then
                            service_installed=true
                        fi
                    fi
                    ;;
            esac
        fi

        # If service file not found in tar.gz, download from GitHub
        if [ "$service_installed" = false ]; then
            echo -e "${yellow}Service files not found in tar.gz, downloading from GitHub...${plain}"
            case "${release}" in
                ubuntu | debian | armbian)
                    curl -4fLRo ${xui_service}/x-ui.service https://raw.githubusercontent.com/MHSanaei/3x-ui/main/x-ui.service.debian > /dev/null 2>&1
                    ;;
                arch | manjaro | parch)
                    curl -4fLRo ${xui_service}/x-ui.service https://raw.githubusercontent.com/MHSanaei/3x-ui/main/x-ui.service.arch > /dev/null 2>&1
                    ;;
                *)
                    curl -4fLRo ${xui_service}/x-ui.service https://raw.githubusercontent.com/MHSanaei/3x-ui/main/x-ui.service.rhel > /dev/null 2>&1
                    ;;
            esac

            if [[ $? -ne 0 ]]; then
                echo -e "${red}Failed to install x-ui.service from GitHub${plain}"
                exit 1
            fi
            service_installed=true
        fi

        if [ "$service_installed" = true ]; then
            echo -e "${green}Setting up systemd unit...${plain}"
            chown root:root ${xui_service}/x-ui.service > /dev/null 2>&1
            chmod 644 ${xui_service}/x-ui.service > /dev/null 2>&1
            systemctl daemon-reload
            systemctl enable x-ui
            systemctl start x-ui
        else
            echo -e "${red}Failed to install x-ui.service file${plain}"
            exit 1
        fi
    fi

    echo -e "${green}x-ui ${tag_version}${plain} installation finished, it is running now..."
    echo -e ""
    echo -e "┌───────────────────────────────────────────────────────┐
│  ${blue}x-ui control menu usages (subcommands):${plain}              │
│                                                       │
│  ${blue}x-ui${plain}              - Admin Management Script          │
│  ${blue}x-ui start${plain}        - Start                            │
│  ${blue}x-ui stop${plain}         - Stop                             │
│  ${blue}x-ui restart${plain}      - Restart                          │
│  ${blue}x-ui status${plain}       - Current Status                   │
│  ${blue}x-ui settings${plain}     - Current Settings                 │
│  ${blue}x-ui enable${plain}       - Enable Autostart on OS Startup   │
│  ${blue}x-ui disable${plain}      - Disable Autostart on OS Startup  │
│  ${blue}x-ui log${plain}          - Check logs                       │
│  ${blue}x-ui banlog${plain}       - Check Fail2ban ban logs          │
│  ${blue}x-ui update${plain}       - Update                           │
│  ${blue}x-ui legacy${plain}       - Legacy version                   │
│  ${blue}x-ui install${plain}      - Install                          │
│  ${blue}x-ui uninstall${plain}    - Uninstall                        │
└───────────────────────────────────────────────────────┘"
}

echo -e "${green}Running...${plain}"
install_base
if [[ -n "${XUI_VERSION}" ]]; then
    install_x-ui "${XUI_VERSION}"
else
    install_x-ui
fi
echo "__IRANUX_REACHED_END_V1__"
exit 0