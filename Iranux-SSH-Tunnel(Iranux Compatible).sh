=== IRANUX_REWRITTEN_SCRIPT_BEGIN ===
#!/usr/bin/env bash

: <<'IRANUX_METADATA'
{
"standard": {
"name": "iranux-script-metadata",
"schema_version": "1.0"
},
"script": {
"id": "secure-web-server-setup",
"name": "Secure Web Server Setup",
"version": "1.0.0",
"description": "Sets up a secure web application environment with optional Nginx or Apache installation, firewall rules, and SSH root login hardening."
},
"risk": {
"level": "high"
},
"requirements": {
"requires_root": true,
"requires_internet": true,
"supported_os": [
"ubuntu",
"debian"
],
"required_commands": [
"id",
"mkdir",
"apt-get",
"systemctl",
"ufw",
"cp",
"sed"
]
}
}
IRANUX_METADATA

echo "=== Secure Web Server Setup ==="

if [[ "$(id -u)" -ne 0 ]]; then
echo "This script must be run as root"
exit 1
fi

: <<'IRANUX_PARAM'
{
"name": "domain",
"label": "Domain Name",
"description": "The domain name used by the secure web application.",
"type": "domain",
"required": true,
"example": "example.com",
"placeholder": "example.com",
"group": "Application Settings"
}
IRANUX_PARAM

DOMAIN="${DOMAIN:-}"

: <<'IRANUX_PARAM'
{
"name": "admin_email",
"label": "Admin Email",
"description": "The administrator email address for the secure web application.",
"type": "email",
"required": true,
"example": "[admin@example.com](mailto:admin@example.com)",
"placeholder": "[admin@example.com](mailto:admin@example.com)",
"group": "Application Settings"
}
IRANUX_PARAM

ADMIN_EMAIL="${ADMIN_EMAIL:-}"

: <<'IRANUX_PARAM'
{
"name": "db_password",
"label": "Database Password",
"description": "The database password written to the application environment file.",
"type": "password",
"required": true,
"sensitive": true,
"group": "Application Settings"
}
IRANUX_PARAM

DB_PASSWORD="${DB_PASSWORD:-}"

: <<'IRANUX_PARAM'
{
"name": "app_port",
"label": "Application Port",
"description": "The TCP port used by the application.",
"type": "port",
"required": true,
"example": 8080,
"placeholder": "8080",
"group": "Network Settings"
}
IRANUX_PARAM

APP_PORT="${APP_PORT:-}"

: <<'IRANUX_PARAM'
{
"name": "web_server",
"label": "Web Server",
"description": "Choose which web server option should be used. The Bash script expects 1 for Nginx, 2 for Apache, or 3 for none.",
"type": "enum",
"required": true,
"options": [
{
"label": "Nginx",
"value": "1"
},
{
"label": "Apache",
"value": "2"
},
{
"label": "None",
"value": "3"
}
],
"group": "Web Server Settings"
}
IRANUX_PARAM

WEB_SERVER="${WEB_SERVER:-}"

: <<'IRANUX_PARAM'
{
"name": "enable_firewall",
"label": "Enable Firewall Rules",
"description": "Choose whether firewall rules should be enabled. The Bash script expects Y or N.",
"type": "enum",
"required": true,
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
"group": "Security Settings"
}
IRANUX_PARAM

ENABLE_FIREWALL="${ENABLE_FIREWALL:-}"

: <<'IRANUX_PARAM'
{
"name": "disable_ssh_root",
"label": "Disable SSH Root Login",
"description": "Choose whether SSH root login should be disabled. The Bash script expects Y or N.",
"type": "enum",
"required": true,
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
"group": "Security Settings"
}
IRANUX_PARAM

DISABLE_SSH_ROOT="${DISABLE_SSH_ROOT:-}"

: <<'IRANUX_PARAM'
{
"name": "restart_services",
"label": "Restart Services After Setup",
"description": "Choose whether affected services should be restarted after setup. The Bash script expects Y or N.",
"type": "enum",
"required": true,
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
"group": "Service Settings"
}
IRANUX_PARAM

RESTART_SERVICES="${RESTART_SERVICES:-}"

if [[ -z "$DOMAIN" ]]; then
echo "Domain is required"
exit 1
fi

if [[ -z "$ADMIN_EMAIL" ]]; then
echo "Admin email is required"
exit 1
fi

if [[ -z "$DB_PASSWORD" ]]; then
echo "Database password is required"
exit 1
fi

if [[ -z "$APP_PORT" ]]; then
echo "Application port is required"
exit 1
fi

mkdir -p /opt/secure-webapp

cat > /opt/secure-webapp/.env <<EOF
DOMAIN=$DOMAIN
ADMIN_EMAIL=$ADMIN_EMAIL
DB_PASSWORD=$DB_PASSWORD
APP_PORT=$APP_PORT
WEB_SERVER=$WEB_SERVER
EOF

if [[ "$WEB_SERVER" == "1" ]]; then
apt-get update -y
apt-get install -y nginx
systemctl enable nginx
elif [[ "$WEB_SERVER" == "2" ]]; then
apt-get update -y
apt-get install -y apache2
systemctl enable apache2
elif [[ "$WEB_SERVER" == "3" ]]; then
echo "No web server selected"
else
echo "Invalid web server option"
exit 1
fi

if [[ "$ENABLE_FIREWALL" == "Y" ]]; then
ufw allow "$APP_PORT"/tcp
ufw allow 22/tcp
ufw --force enable
fi

if [[ "$DISABLE_SSH_ROOT" == "Y" ]]; then
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sed -i "s/^#\?PermitRootLogin .*/PermitRootLogin no/" /etc/ssh/sshd_config
fi

if [[ "$RESTART_SERVICES" == "Y" ]]; then
if [[ "$WEB_SERVER" == "1" ]]; then
systemctl restart nginx
elif [[ "$WEB_SERVER" == "2" ]]; then
systemctl restart apache2
fi

if [[ "$DISABLE_SSH_ROOT" == "Y" ]]; then
systemctl restart ssh
fi
fi

echo "Secure web server setup completed"
echo "**IRANUX_REACHED_END_V1**"
exit 0
=== IRANUX_REWRITTEN_SCRIPT_END ===

=== IRANUX_CONVERSION_REPORT_BEGIN ===
Source reviewed: 

The uploaded Bash script already contained Iranux-style metadata and parameter blocks, so the script logic was preserved as provided.

Detected and preserved exactly one IRANUX_METADATA block with required standard, script, and risk fields.

Detected and preserved 8 IRANUX_PARAM blocks:

* domain
* admin_email
* db_password
* app_port
* web_server
* enable_firewall
* disable_ssh_root
* restart_services

Interactive-style inputs are represented as Iranux parameters. Menu and Y/N choices are modeled as enum values using the exact Bash-facing values expected by the script.

The database password parameter is marked as password and sensitive.

No IRANUX_CERTIFICATION block was added.

The final Iranux marker is present only in the successful normal execution path immediately before exit 0.
=== IRANUX_CONVERSION_REPORT_END ===

=== IRANUX_DETECTED_PARAMETERS_BEGIN ===
[
{
"name": "domain",
"label": "Domain Name",
"description": "The domain name used by the secure web application.",
"type": "domain",
"required": true,
"example": "example.com",
"placeholder": "example.com",
"group": "Application Settings"
},
{
"name": "admin_email",
"label": "Admin Email",
"description": "The administrator email address for the secure web application.",
"type": "email",
"required": true,
"example": "[admin@example.com](mailto:admin@example.com)",
"placeholder": "[admin@example.com](mailto:admin@example.com)",
"group": "Application Settings"
},
{
"name": "db_password",
"label": "Database Password",
"description": "The database password written to the application environment file.",
"type": "password",
"required": true,
"sensitive": true,
"group": "Application Settings"
},
{
"name": "app_port",
"label": "Application Port",
"description": "The TCP port used by the application.",
"type": "port",
"required": true,
"example": 8080,
"placeholder": "8080",
"group": "Network Settings"
},
{
"name": "web_server",
"label": "Web Server",
"description": "Choose which web server option should be used. The Bash script expects 1 for Nginx, 2 for Apache, or 3 for none.",
"type": "enum",
"required": true,
"options": [
{
"label": "Nginx",
"value": "1"
},
{
"label": "Apache",
"value": "2"
},
{
"label": "None",
"value": "3"
}
],
"group": "Web Server Settings"
},
{
"name": "enable_firewall",
"label": "Enable Firewall Rules",
"description": "Choose whether firewall rules should be enabled. The Bash script expects Y or N.",
"type": "enum",
"required": true,
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
"group": "Security Settings"
},
{
"name": "disable_ssh_root",
"label": "Disable SSH Root Login",
"description": "Choose whether SSH root login should be disabled. The Bash script expects Y or N.",
"type": "enum",
"required": true,
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
"group": "Security Settings"
},
{
"name": "restart_services",
"label": "Restart Services After Setup",
"description": "Choose whether affected services should be restarted after setup. The Bash script expects Y or N.",
"type": "enum",
"required": true,
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
"group": "Service Settings"
}
]
=== IRANUX_DETECTED_PARAMETERS_END ===

=== IRANUX_WARNINGS_BEGIN ===
This is an Iranux Compatible candidate only. It is not Iranux Verified and contains no IRANUX_CERTIFICATION block.

Risk level is high because the script can install packages, enable services, modify firewall rules with ufw, edit /etc/ssh/sshd_config, and restart SSH.

The script writes DB_PASSWORD into /opt/secure-webapp/.env. The value is not printed, but the resulting file should be protected with appropriate filesystem permissions.

The script enables ufw and allows port 22/tcp and the configured application port. Human review is recommended before running on remote servers to avoid accidental lockout.

The script modifies SSH root login settings and may restart ssh. Human review is recommended because SSH configuration errors can interrupt remote access.

The script assumes apt-get, ufw, systemctl, and Debian/Ubuntu-style service names. Compatibility with other Linux distributions is not implied.

No set -euo pipefail was added.
=== IRANUX_WARNINGS_END ===
