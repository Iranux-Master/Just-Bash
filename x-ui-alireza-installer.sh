#!/bin/bash

: <<'IRANUX_METADATA'
{
  "standard": {
    "name": "iranux-script-metadata",
    "schema_version": "1.2"
  },
  "script": {
    "id": "x-ui-alireza-installer",
    "name": "x-ui Alireza Installer",
    "version": "1.0.0",
    "description": "Installs or updates the alireza0/x-ui panel: updates system packages, downloads the selected release, installs the systemd service, migrates settings, and can restore a backup left by a failed installation. On a new installation it creates a random admin login, port and panel path.",
    "estimated_minutes": 5,
    "i18n": {
      "fa": {
        "name": "نصب پنل x-ui (Alireza)",
        "description": "پنل alireza0/x-ui را نصب یا به‌روزرسانی می‌کند: بسته‌های سیستم را به‌روزرسانی می‌کند، نسخه‌ی انتخاب‌شده را دانلود می‌کند، سرویس systemd را نصب می‌کند، تنظیمات را منتقل می‌کند و می‌تواند نسخه‌ی پشتیبانِ مانده از یک نصب ناموفق را بازیابی کند. در نصب جدید، نام کاربری، رمز عبور، پورت و مسیر پنل به‌صورت تصادفی ساخته می‌شود."
      }
    }
  },
  "risk": {
    "level": "high"
  },
  "requirements": {
    "requires_root": true,
    "requires_internet": true,
    "supported_os": [
      "ubuntu",
      "debian",
      "armbian",
      "centos",
      "almalinux",
      "rocky",
      "ol",
      "fedora",
      "amzn",
      "arch",
      "manjaro",
      "parch",
      "opensuse-tumbleweed"
    ],
    "required_commands": [
      "systemctl"
    ]
  },
  "ui": {
    "category": {
      "id": "proxy-management",
      "name": "Proxy Management"
    },
    "action": {
      "id": "management-panel-installers",
      "name": "Management Panel Installers"
    },
    "icon": {
      "library": "mdi",
      "name": "view-dashboard-outline"
    }
  }
}
IRANUX_METADATA

: <<'IRANUX_PARAM'
{
  "name": "target_version",
  "label": "Version",
  "description": "Enter the x-ui release to install, for example v1.8.0. Leave empty to install the latest release.",
  "type": "string",
  "required": false,
  "placeholder": "v1.8.0",
  "group": "Download Settings",
  "level": "advanced",
  "i18n": {
    "fa": {
      "label": "نسخه",
      "description": "نسخه‌ی x-ui را که می‌خواهید نصب شود وارد کنید، مثلاً v1.8.0. برای نصب آخرین نسخه، خالی بگذارید."
    }
  }
}
IRANUX_PARAM

: <<'IRANUX_PARAM'
{
  "name": "restore_backup",
  "label": "Restore backup of a failed installation",
  "description": "If a backup from a failed installation exists in /usr/local/x-ui-backup, choose whether to restore it instead of installing again. If you choose No, that backup is deleted after the new installation.",
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
  "group": "Recovery Settings",
  "i18n": {
    "fa": {
      "label": "بازیابی نسخه‌ی پشتیبان نصب ناموفق",
      "description": "اگر نسخه‌ی پشتیبانی از یک نصب ناموفق در /usr/local/x-ui-backup وجود دارد، انتخاب کنید که به‌جای نصب دوباره، بازیابی شود یا نه. اگر «خیر» را انتخاب کنید، آن نسخه‌ی پشتیبان بعد از نصب جدید حذف می‌شود."
    }
  }
}
IRANUX_PARAM

: <<'IRANUX_PARAM'
{
  "name": "customize_panel_port",
  "label": "Choose the panel port",
  "description": "Choose whether to use your own panel port on a new installation. If you choose No, a random port is used.",
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
  "group": "Panel Settings",
  "i18n": {
    "fa": {
      "label": "انتخاب پورت پنل",
      "description": "انتخاب کنید که در نصب جدید، پورت دلخواه شما برای پنل استفاده شود یا نه. اگر «خیر» را انتخاب کنید، یک پورت تصادفی استفاده می‌شود."
    }
  }
}
IRANUX_PARAM

: <<'IRANUX_PARAM'
{
  "name": "panel_port",
  "label": "Panel port",
  "description": "Enter the port the panel listens on. Used only when Choose the panel port is Yes. Leave empty to get a random port.",
  "type": "port",
  "required": false,
  "example": 54321,
  "group": "Panel Settings",
  "generate": "port",
  "i18n": {
    "fa": {
      "label": "پورت پنل",
      "description": "پورتی را که پنل روی آن کار می‌کند وارد کنید. فقط وقتی استفاده می‌شود که «انتخاب پورت پنل» روی «بله» باشد. برای گرفتن یک پورت تصادفی، خالی بگذارید."
    }
  }
}
IRANUX_PARAM

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# Iranux: JSON string escaping for the IRANUX_RESULT line (specification Appendix C).
iranux_json_string() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\t'/\\t}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\n'/\\n}"
  printf '"%s"' "$s"
}

# Iranux: values reported in the IRANUX_RESULT line (empty values are left out).
iranux_result_panel_port=""
iranux_result_panel_path=""
iranux_result_username=""
iranux_result_credentials_file=""
iranux_outputs=""
iranux_add_output() {
    # $1 key, $2 English label, $3 value, $4 type, $5 Persian label
    [[ -n "$3" ]] || return 0
    [[ -z "$iranux_outputs" ]] || iranux_outputs+=","
    iranux_outputs+="{\"key\":\"$1\",\"label\":\"$2\",\"value\":$(iranux_json_string "$3"),\"type\":\"$4\",\"i18n\":{\"fa\":{\"label\":\"$5\"}}}"
}
iranux_print_result() {
    iranux_add_output "panel_port" "Panel port" "$iranux_result_panel_port" "text" "پورت پنل"
    iranux_add_output "panel_path" "Panel path" "$iranux_result_panel_path" "text" "مسیر پنل"
    iranux_add_output "admin_username" "Admin username" "$iranux_result_username" "copy" "نام کاربری مدیر"
    iranux_add_output "credentials_file" "Login details file" "$iranux_result_credentials_file" "text" "فایل اطلاعات ورود"
    iranux_add_output "installed_version" "Installed version" "$last_version" "text" "نسخه‌ی نصب‌شده"
    echo "IRANUX_RESULT {\"outputs\":[${iranux_outputs}]}"
}

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

echo "arch: $(arch)"

install_dependencies() {
    case "${release}" in
    ubuntu | debian | armbian)
        apt-get update && apt-get install -y -q wget curl tar tzdata cron
        ;;
    centos | almalinux | rocky | ol)
        yum -y update && yum install -y -q wget curl tar tzdata cronie
        ;;
    fedora | amzn)
        dnf -y update && dnf install -y -q wget curl tar tzdata cronie
        ;;
    arch | manjaro | parch)
        pacman -Syu && pacman -Syu --noconfirm wget curl tar tzdata cronie
        ;;
    opensuse-tumbleweed)
        zypper refresh && zypper -q install -y wget curl tar timezone cron
        ;;
    *)
        apt-get update && apt install -y -q wget curl tar tzdata cron
        ;;
    esac
}

gen_random_string() {
    local length="$1"
    local random_string=$(LC_ALL=C tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w "$length" | head -n 1)
    echo "$random_string"
}

config_after_install() {
    local existing_username=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'username: .+' | awk '{print $2}')
    local existing_password=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'password: .+' | awk '{print $2}')
    local existing_webBasePath=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'webBasePath: .+' | awk '{print $2}')

    if [[ ${#existing_webBasePath} -lt 4 ]]; then
        if [[ "$existing_username" == "admin" && "$existing_password" == "admin" ]]; then
            local config_webBasePath=$(gen_random_string 15)
            local config_username=$(gen_random_string 10)
            local config_password=$(gen_random_string 10)

            local config_confirm="${CUSTOMIZE_PANEL_PORT:-N}"
            local config_port=""
            if [[ "${config_confirm}" == "y" || "${config_confirm}" == "Y" ]]; then
                config_port="${PANEL_PORT:-}"
                if [[ -n "${config_port}" ]]; then
                    echo -e "${yellow}Your Panel Port is: ${config_port}${plain}"
                else
                    config_port=$(shuf -i 1024-62000 -n 1)
                    echo -e "${yellow}PANEL_PORT was empty; generated random port: ${config_port}${plain}"
                fi
            else
                config_port=$(shuf -i 1024-62000 -n 1)
                echo -e "${yellow}Generated random port: ${config_port}${plain}"
            fi

            /usr/local/x-ui/x-ui setting -username "${config_username}" -password "${config_password}" -port "${config_port}" -webBasePath "${config_webBasePath}"
            echo -e "This is a fresh installation, generating random login info for security concerns:"
            echo -e "###############################################"
            # Iranux: the generated login is written to a root-only file instead of the log.
            ( umask 077; printf 'username: %s\npassword: %s\n' "${config_username}" "${config_password}" > /root/x-ui-credentials.txt )
            echo -e "${green}Username and password saved to /root/x-ui-credentials.txt (readable by root only)${plain}"
            echo -e "${green}Port: ${config_port}${plain}"
            echo -e "${green}WebBasePath: ${config_webBasePath}${plain}"
            iranux_result_username="$config_username"
            iranux_result_panel_port="$config_port"
            iranux_result_panel_path="$config_webBasePath"
            iranux_result_credentials_file="/root/x-ui-credentials.txt"
            echo -e "###############################################"
            echo -e "${yellow}If you forgot your login info, you can type 'x-ui settings' to check${plain}"
        else
            local config_webBasePath=$(gen_random_string 15)
            echo -e "${yellow}WebBasePath is missing or too short. Generating a new one...${plain}"
            /usr/local/x-ui/x-ui setting -webBasePath "${config_webBasePath}"
            echo -e "${green}New WebBasePath: ${config_webBasePath}${plain}"
            iranux_result_username="$existing_username"
            iranux_result_panel_path="$config_webBasePath"
        fi
    else
        if [[ "$existing_username" == "admin" && "$existing_password" == "admin" ]]; then
            local config_username=$(gen_random_string 10)
            local config_password=$(gen_random_string 10)

            echo -e "${yellow}Default credentials detected. Security update required...${plain}"
            /usr/local/x-ui/x-ui setting -username "${config_username}" -password "${config_password}"
            echo -e "Generated new random login credentials:"
            echo -e "###############################################"
            # Iranux: the generated login is written to a root-only file instead of the log.
            ( umask 077; printf 'username: %s\npassword: %s\n' "${config_username}" "${config_password}" > /root/x-ui-credentials.txt )
            echo -e "${green}Username and password saved to /root/x-ui-credentials.txt (readable by root only)${plain}"
            iranux_result_username="$config_username"
            iranux_result_panel_path="$existing_webBasePath"
            iranux_result_credentials_file="/root/x-ui-credentials.txt"
            echo -e "###############################################"
            echo -e "${yellow}If you forgot your login info, you can type 'x-ui settings' to check${plain}"
        else
            echo -e "${green}Username, Password, and WebBasePath are properly set. Exiting...${plain}"
            iranux_result_username="$existing_username"
            iranux_result_panel_path="$existing_webBasePath"
        fi
    fi

    /usr/local/x-ui/x-ui migrate
}

install_x-ui() {
    # checks if the installation backup dir exist. if existed then restore only when requested by Iranux parameter.
    if [[ -e /usr/local/x-ui-backup/ ]]; then
        local restore_confirm="${RESTORE_BACKUP:-N}"
        if [[ "${restore_confirm}" == "y" || "${restore_confirm}" == "Y" ]]; then
            systemctl stop x-ui
            mv /usr/local/x-ui-backup/x-ui.db /etc/x-ui/ -f
            mv /usr/local/x-ui-backup/ /usr/local/x-ui/ -f
            systemctl start x-ui
            echo -e "${green}previous installed x-ui restored successfully${plain}, it is up and running now..."
            iranux_print_result
            echo "__IRANUX_REACHED_END_V1__"
            exit 0
        else
            echo -e "Continuing installing x-ui ..."
        fi
    fi

    cd /usr/local/

    if [ $# == 0 ]; then
        last_version=$(curl -Ls "https://api.github.com/repos/alireza0/x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Failed to fetch x-ui version, it maybe due to Github API restrictions, please try it later${plain}"
            exit 1
        fi
        echo -e "Got x-ui latest version: ${last_version}, beginning the installation..."
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-$(arch).tar.gz https://github.com/alireza0/x-ui/releases/download/${last_version}/x-ui-linux-$(arch).tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Downloading x-ui failed, please be sure that your server can access Github ${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/alireza0/x-ui/releases/download/${last_version}/x-ui-linux-$(arch).tar.gz"
        echo -e "Beginning to install x-ui $1"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-$(arch).tar.gz "${url}"
        if [[ $? -ne 0 ]]; then
            echo -e "${red}download x-ui $1 failed,please check the version exists${plain}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/x-ui/ ]]; then
        systemctl stop x-ui
        mv /usr/local/x-ui/ /usr/local/x-ui-backup/ -f
        cp /etc/x-ui/x-ui.db /usr/local/x-ui-backup/ -f
    fi

    tar zxvf x-ui-linux-$(arch).tar.gz
    rm x-ui-linux-$(arch).tar.gz -f
    cd x-ui
    chmod +x x-ui

    # Check the system's architecture and rename the file accordingly
    if [[ $(arch) == "armv7" ]]; then
        mv bin/xray-linux-$(arch) bin/xray-linux-arm
        chmod +x bin/xray-linux-arm
    fi
    chmod +x x-ui bin/xray-linux-$(arch)
    cp -f x-ui.service /etc/systemd/system/
    wget --no-check-certificate -O /usr/bin/x-ui https://raw.githubusercontent.com/alireza0/x-ui/main/x-ui.sh
    chmod +x /usr/local/x-ui/x-ui.sh
    chmod +x /usr/bin/x-ui
    config_after_install
    rm /usr/local/x-ui-backup/ -rf
    #echo -e "If it is a new installation, the default web port is ${green}54321${plain}, The username and password are ${green}admin${plain} by default"
    #echo -e "Please make sure that this port is not occupied by other procedures,${yellow} And make sure that port 54321 has been released${plain}"
    #    echo -e "If you want to modify the 54321 to other ports and enter the x-ui command to modify it, you must also ensure that the port you modify is also released"
    #echo -e ""
    #echo -e "If it is updated panel, access the panel in your previous way"
    #echo -e ""
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    echo -e "${green}x-ui ${last_version}${plain} installation finished, it is up and running now..."
    echo -e ""
    echo -e "You may access the Panel with following URL(s):${yellow}"
    /usr/local/x-ui/x-ui uri
    echo -e "${plain}"
    echo "X-UI Control Menu Usage"
    echo "------------------------------------------"
    echo "SUBCOMMANDS:"
    echo "x-ui              - Admin Management Script"
    echo "x-ui start        - Start"
    echo "x-ui stop         - Stop"
    echo "x-ui restart      - Restart"
    echo "x-ui status       - Current Status"
    echo "x-ui settings     - Current Settings"
    echo "x-ui enable       - Enable Autostart on OS Startup"
    echo "x-ui disable      - Disable Autostart on OS Startup"
    echo "x-ui log          - Check Logs"
    echo "x-ui update       - Update"
    echo "x-ui install      - Install"
    echo "x-ui uninstall    - Uninstall"
    echo "x-ui help         - Control Menu Usage"
    echo "------------------------------------------"
}

echo -e "${green}Running...${plain}"
TARGET_VERSION="${TARGET_VERSION:-${1:-}}"
install_dependencies
if [[ -n "${TARGET_VERSION}" ]]; then
    install_x-ui "${TARGET_VERSION}"
else
    install_x-ui
fi

iranux_print_result
echo "__IRANUX_REACHED_END_V1__"
exit 0
