#!/bin/bash

: <<'IRANUX_METADATA'
{
  "standard": {
    "name": "iranux-script-metadata",
    "schema_version": "1.2"
  },
  "script": {
    "id": "s-ui-alireza-installer",
    "name": "s-ui Alireza Installer",
    "version": "1.0.0",
    "description": "Installs or updates the alireza0/s-ui panel: updates system packages, downloads the selected release, installs the systemd service, migrates settings, and optionally sets the panel, subscription and admin settings.",
    "estimated_minutes": 5,
    "i18n": {
      "fa": {
        "name": "نصب پنل s-ui (Alireza)",
        "description": "پنل alireza0/s-ui را نصب یا به‌روزرسانی می‌کند: بسته‌های سیستم را به‌روزرسانی می‌کند، نسخه‌ی انتخاب‌شده را دانلود می‌کند، سرویس systemd را نصب می‌کند، تنظیمات را منتقل می‌کند و در صورت انتخاب شما، تنظیمات پنل، اشتراک و مدیر را اعمال می‌کند."
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
      "centos",
      "almalinux",
      "rocky",
      "ol",
      "fedora",
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
  "description": "Enter the s-ui release to install, for example v1.2.3. Leave empty to install the latest release.",
  "type": "string",
  "required": false,
  "placeholder": "v1.2.3",
  "group": "Download Settings",
  "level": "advanced",
  "i18n": {
    "fa": {
      "label": "نسخه",
      "description": "نسخه‌ی s-ui را که می‌خواهید نصب شود وارد کنید، مثلاً v1.2.3. برای نصب آخرین نسخه، خالی بگذارید."
    }
  }
}
IRANUX_PARAM

: <<'IRANUX_PARAM'
{
  "name": "configure_panel",
  "label": "Configure panel settings",
  "description": "Choose whether to set the panel and subscription port and path after installation. If you choose No on a new installation, a random admin username and password are created.",
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
      "label": "پیکربندی تنظیمات پنل",
      "description": "انتخاب کنید که پورت و مسیر پنل و اشتراک بعد از نصب تنظیم شود یا نه. اگر در نصب جدید «خیر» را انتخاب کنید، یک نام کاربری و رمز عبور تصادفی برای مدیر ساخته می‌شود."
    }
  }
}
IRANUX_PARAM

: <<'IRANUX_PARAM'
{
  "name": "panel_port",
  "label": "Panel port",
  "description": "Enter the port the panel listens on. Used only when Configure panel settings is Yes. Leave empty to keep the current port.",
  "type": "port",
  "required": false,
  "example": 2095,
  "group": "Panel Settings",
  "i18n": {
    "fa": {
      "label": "پورت پنل",
      "description": "پورتی را که پنل روی آن کار می‌کند وارد کنید. فقط وقتی استفاده می‌شود که «پیکربندی تنظیمات پنل» روی «بله» باشد. برای نگه داشتن پورت فعلی، خالی بگذارید."
    }
  }
}
IRANUX_PARAM

: <<'IRANUX_PARAM'
{
  "name": "panel_path",
  "label": "Panel path",
  "description": "Enter the path of the panel address, for example admin. Used only when Configure panel settings is Yes. Leave empty to keep the current path.",
  "type": "string",
  "required": false,
  "placeholder": "admin",
  "group": "Panel Settings",
  "level": "advanced",
  "i18n": {
    "fa": {
      "label": "مسیر پنل",
      "description": "مسیر آدرس پنل را وارد کنید، مثلاً admin. فقط وقتی استفاده می‌شود که «پیکربندی تنظیمات پنل» روی «بله» باشد. برای نگه داشتن مسیر فعلی، خالی بگذارید."
    }
  }
}
IRANUX_PARAM

: <<'IRANUX_PARAM'
{
  "name": "subscription_port",
  "label": "Subscription port",
  "description": "Enter the port for subscription links. Used only when Configure panel settings is Yes. Leave empty to keep the current port.",
  "type": "port",
  "required": false,
  "example": 2096,
  "group": "Subscription Settings",
  "level": "advanced",
  "i18n": {
    "fa": {
      "label": "پورت اشتراک",
      "description": "پورت لینک‌های اشتراک را وارد کنید. فقط وقتی استفاده می‌شود که «پیکربندی تنظیمات پنل» روی «بله» باشد. برای نگه داشتن پورت فعلی، خالی بگذارید."
    }
  }
}
IRANUX_PARAM

: <<'IRANUX_PARAM'
{
  "name": "subscription_path",
  "label": "Subscription path",
  "description": "Enter the path of subscription links, for example sub. Used only when Configure panel settings is Yes. Leave empty to keep the current path.",
  "type": "string",
  "required": false,
  "placeholder": "sub",
  "group": "Subscription Settings",
  "level": "advanced",
  "i18n": {
    "fa": {
      "label": "مسیر اشتراک",
      "description": "مسیر لینک‌های اشتراک را وارد کنید، مثلاً sub. فقط وقتی استفاده می‌شود که «پیکربندی تنظیمات پنل» روی «بله» باشد. برای نگه داشتن مسیر فعلی، خالی بگذارید."
    }
  }
}
IRANUX_PARAM

: <<'IRANUX_PARAM'
{
  "name": "change_admin_credentials",
  "label": "Change admin username and password",
  "description": "Choose whether to set a new admin username and password. Used only when Configure panel settings is Yes. If you choose No, the current admin login is shown in the log.",
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
  "group": "Admin Settings",
  "i18n": {
    "fa": {
      "label": "تغییر نام کاربری و رمز عبور مدیر",
      "description": "انتخاب کنید که نام کاربری و رمز عبور تازه‌ای برای مدیر تنظیم شود یا نه. فقط وقتی استفاده می‌شود که «پیکربندی تنظیمات پنل» روی «بله» باشد. اگر «خیر» را انتخاب کنید، اطلاعات ورود فعلی مدیر در گزارش اجرا نشان داده می‌شود."
    }
  }
}
IRANUX_PARAM

: <<'IRANUX_PARAM'
{
  "name": "admin_username",
  "label": "Admin username",
  "description": "Enter the username for signing in to the panel. Used only when Change admin username and password is Yes.",
  "type": "string",
  "required": false,
  "placeholder": "admin",
  "group": "Admin Settings",
  "i18n": {
    "fa": {
      "label": "نام کاربری مدیر",
      "description": "نام کاربری برای ورود به پنل را وارد کنید. فقط وقتی استفاده می‌شود که «تغییر نام کاربری و رمز عبور مدیر» روی «بله» باشد."
    }
  }
}
IRANUX_PARAM

: <<'IRANUX_PARAM'
{
  "name": "admin_password",
  "label": "Admin password",
  "description": "Enter the password for signing in to the panel. Used only when Change admin username and password is Yes.",
  "type": "password",
  "required": false,
  "sensitive": true,
  "group": "Admin Settings",
  "i18n": {
    "fa": {
      "label": "رمز عبور مدیر",
      "description": "رمز عبور برای ورود به پنل را وارد کنید. فقط وقتی استفاده می‌شود که «تغییر نام کاربری و رمز عبور مدیر» روی «بله» باشد."
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
iranux_result_sub_port=""
iranux_result_sub_path=""
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
    iranux_add_output "subscription_port" "Subscription port" "$iranux_result_sub_port" "text" "پورت اشتراک"
    iranux_add_output "subscription_path" "Subscription path" "$iranux_result_sub_path" "text" "مسیر اشتراک"
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

install_base() {
    case "${release}" in
    centos | almalinux | rocky | oracle)
        yum -y update && yum install -y -q wget curl tar tzdata
        ;;
    fedora)
        dnf -y update && dnf install -y -q wget curl tar tzdata
        ;;
    arch | manjaro | parch)
        pacman -Syu && pacman -Syu --noconfirm wget curl tar tzdata
        ;;
    opensuse-tumbleweed)
        zypper refresh && zypper -q install -y wget curl tar timezone
        ;;
    *)
        apt-get update && apt-get install -y -q wget curl tar tzdata
        ;;
    esac
}

config_after_install() {
    echo -e "${yellow}Migration... ${plain}"
    /usr/local/s-ui/sui migrate

    echo -e "${yellow}Install/update finished! For security it's recommended to modify panel settings ${plain}"
    local config_confirm="${CONFIGURE_PANEL:-N}"
    if [[ "${config_confirm}" == "y" || "${config_confirm}" == "Y" ]]; then
        local config_port="${PANEL_PORT:-}"
        local config_path="${PANEL_PATH:-}"
        local config_subPort="${SUBSCRIPTION_PORT:-}"
        local config_subPath="${SUBSCRIPTION_PATH:-}"

        # Set configs
        echo -e "${yellow}Initializing, please wait...${plain}"
        params=()
        [ -z "$config_port" ] || params+=(-port "$config_port")
        [ -z "$config_path" ] || params+=(-path "$config_path")
        [ -z "$config_subPort" ] || params+=(-subPort "$config_subPort")
        [ -z "$config_subPath" ] || params+=(-subPath "$config_subPath")
        /usr/local/s-ui/sui setting "${params[@]}"
        iranux_result_panel_port="$config_port"
        iranux_result_panel_path="$config_path"
        iranux_result_sub_port="$config_subPort"
        iranux_result_sub_path="$config_subPath"

        local admin_confirm="${CHANGE_ADMIN_CREDENTIALS:-N}"
        if [[ "${admin_confirm}" == "y" || "${admin_confirm}" == "Y" ]]; then
            # First admin credentials
            local config_account="${ADMIN_USERNAME:-}"
            local config_password="${ADMIN_PASSWORD:-}"

            # Set credentials
            echo -e "${yellow}Initializing, please wait...${plain}"
            /usr/local/s-ui/sui admin -username "${config_account}" -password "${config_password}"
            iranux_result_username="$config_account"
        else
            echo -e "${yellow}Your current admin credentials: ${plain}"
            /usr/local/s-ui/sui admin -show
        fi
    else
        echo -e "${red}cancel...${plain}"
        if [[ ! -f "/usr/local/s-ui/db/s-ui.db" ]]; then
            local usernameTemp=$(head -c 6 /dev/urandom | base64)
            local passwordTemp=$(head -c 6 /dev/urandom | base64)
            echo -e "this is a fresh installation,will generate random login info for security concerns:"
            echo -e "###############################################"
            # Iranux: the generated login is written to a root-only file instead of the log.
            ( umask 077; printf 'username: %s\npassword: %s\n' "${usernameTemp}" "${passwordTemp}" > /root/s-ui-credentials.txt )
            echo -e "${green}username and password saved to /root/s-ui-credentials.txt (readable by root only)${plain}"
            iranux_result_username="$usernameTemp"
            iranux_result_credentials_file="/root/s-ui-credentials.txt"
            echo -e "###############################################"
            echo -e "${red}if you forgot your login info,you can type ${green}s-ui${red} for configuration menu${plain}"
            /usr/local/s-ui/sui admin -username ${usernameTemp} -password ${passwordTemp}
        else
            echo -e "${red} this is your upgrade,will keep old settings,if you forgot your login info,you can type ${green}s-ui${red} for configuration menu${plain}"
        fi
    fi
}

prepare_services() {
    if [[ -f "/etc/systemd/system/sing-box.service" ]]; then
        echo -e "${yellow}Stopping sing-box service... ${plain}"
        systemctl stop sing-box
        rm -f /usr/local/s-ui/bin/sing-box /usr/local/s-ui/bin/runSingbox.sh /usr/local/s-ui/bin/signal
    fi
    if [[ -e "/usr/local/s-ui/bin" ]]; then
        echo -e "###############################################################"
        echo -e "${green}/usr/local/s-ui/bin${red} directory exists yet!"
        echo -e "Please check the content and delete it manually after migration ${plain}"
        echo -e "###############################################################"
    fi
    systemctl daemon-reload
}

install_s-ui() {
    cd /tmp/

    if [ $# == 0 ]; then
        last_version=$(curl -Ls "https://api.github.com/repos/alireza0/s-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Failed to fetch s-ui version, it maybe due to Github API restrictions, please try it later${plain}"
            exit 1
        fi
        echo -e "Got s-ui latest version: ${last_version}, beginning the installation..."
        wget -N --no-check-certificate -O /tmp/s-ui-linux-$(arch).tar.gz https://github.com/alireza0/s-ui/releases/download/${last_version}/s-ui-linux-$(arch).tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Downloading s-ui failed, please be sure that your server can access Github ${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/alireza0/s-ui/releases/download/${last_version}/s-ui-linux-$(arch).tar.gz"
        echo -e "Beginning the install s-ui v$1"
        wget -N --no-check-certificate -O /tmp/s-ui-linux-$(arch).tar.gz "${url}"
        if [[ $? -ne 0 ]]; then
            echo -e "${red}download s-ui v$1 failed,please check the version exists${plain}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/s-ui/ ]]; then
        systemctl stop s-ui
    fi

    tar zxvf s-ui-linux-$(arch).tar.gz
    rm s-ui-linux-$(arch).tar.gz -f

    chmod +x s-ui/sui s-ui/s-ui.sh
    cp s-ui/s-ui.sh /usr/bin/s-ui
    cp -rf s-ui /usr/local/
    cp -f s-ui/*.service /etc/systemd/system/
    rm -rf s-ui

    config_after_install
    prepare_services

    systemctl enable s-ui --now

    echo -e "${green}s-ui v${last_version}${plain} installation finished, it is up and running now..."
    echo -e "You may access the Panel with following URL(s):${green}"
    /usr/local/s-ui/sui uri
    echo -e "${plain}"
    echo -e ""
    s-ui help
}

echo -e "${green}Executing...${plain}"
TARGET_VERSION="${TARGET_VERSION:-${1:-}}"
install_base
if [[ -n "${TARGET_VERSION}" ]]; then
    install_s-ui "${TARGET_VERSION}"
else
    install_s-ui
fi

iranux_print_result
echo "__IRANUX_REACHED_END_V1__"
exit 0
