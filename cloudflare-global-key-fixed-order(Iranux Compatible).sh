#!/usr/bin/env bash

: <<'IRANUX_METADATA'
{
  "standard": {
    "name": "iranux-script-metadata",
    "schema_version": "1.1"
  },
  "script": {
    "id": "cloudflare-global-key-fixed-order-auto-parking",
    "name": "Cloudflare Global Key Fixed-Order Auto Parking",
    "version": "1.0.0",
    "description": "Adds or reuses a Cloudflare full zone using Global API Key authentication, creates or updates fixed A and NS records, and uses fixed-order non-interactive inputs for domain, IPv4, account ID, email, and global API key."
  },
  "risk": {
    "level": "high"
  },
  "requirements": {
    "requires_root": false,
    "requires_internet": true,
    "supported_os": [
      "ubuntu",
      "debian"
    ],
    "required_commands": [
      "curl",
      "jq"
    ]
  },
  "ui": {
    "category": {
      "id": "dns-and-domains",
      "name": "DNS and Domains"
    },
    "action": {
      "id": "cloudflare-zone-management",
      "name": "Cloudflare Zone Management"
    },
    "icon": {
      "library": "mdi",
      "name": "key-variant"
    }
  }
}
IRANUX_METADATA

: <<'IRANUX_PARAM'
{
  "name": "cf_domain",
  "label": "Domain",
  "description": "Root domain to add or manage in Cloudflare, for example amirab.sbs. The script normalizes URLs to a root hostname.",
  "type": "domain",
  "required": true,
  "example": "amirab.sbs",
  "group": "DNS Settings"
}
IRANUX_PARAM

: <<'IRANUX_PARAM'
{
  "name": "cf_server_ipv4",
  "label": "Server IPv4 Address",
  "description": "IPv4 address used for the root A record and ns A record.",
  "type": "ipv4",
  "required": true,
  "example": "192.0.2.10",
  "group": "DNS Settings"
}
IRANUX_PARAM

: <<'IRANUX_PARAM'
{
  "name": "cf_account_id",
  "label": "Cloudflare Account ID",
  "description": "Cloudflare account ID where the full zone should be created or managed.",
  "type": "string",
  "required": true,
  "group": "Cloudflare Credentials"
}
IRANUX_PARAM

: <<'IRANUX_PARAM'
{
  "name": "cf_email",
  "label": "Cloudflare Account Email",
  "description": "Cloudflare account email used with Global API Key authentication headers.",
  "type": "email",
  "required": true,
  "example": "you@example.com",
  "group": "Cloudflare Credentials"
}
IRANUX_PARAM

: <<'IRANUX_PARAM'
{
  "name": "cf_global_api_key",
  "label": "Cloudflare Global API Key",
  "description": "Cloudflare Global API Key used as X-Auth-Key. This value is highly sensitive and must not be logged or displayed.",
  "type": "secret",
  "required": true,
  "sensitive": true,
  "group": "Cloudflare Credentials"
}
IRANUX_PARAM

set -Eeuo pipefail

# Cloudflare Global API Key Auto Parking Script
# Target OS: Ubuntu/Debian
#
# Authentication method:
#   X-Auth-Email: <Cloudflare account email>
#   X-Auth-Key:   <Cloudflare Global API Key>
#
# Interactive input order:
#   1) Domain, e.g. amirab.sbs
#   2) Server IPv4
#   3) Cloudflare Account ID
#   4) Cloudflare account email
#   5) Cloudflare Global API Key
#
# Optional environment variables for non-interactive/app usage:
#   CF_DOMAIN="amirab.sbs"
#   CF_SERVER_IPV4="1.2.3.4"
#   CF_ACCOUNT_ID="..."
#   CF_EMAIL="you@example.com"
#   CF_GLOBAL_API_KEY="..."
#
# Optional positional arguments:
#   ./script.sh <domain> <ipv4> <account_id> <email> <global_api_key>
#
# Actions:
#   - Adds/parks the domain in Cloudflare as a full zone
#   - Prints Cloudflare name servers
#   - Creates/updates:
#       A  @              -> USER_IP       proxied=false
#       A  ns             -> USER_IP       proxied=false
#       NS v              -> ns.DOMAIN
#       NS vs             -> ns.DOMAIN
#       NS s              -> ns.DOMAIN
#       NS ss             -> ns.DOMAIN
#       NS t              -> ns.DOMAIN
#       NS ts             -> ns.DOMAIN

API_BASE="https://api.cloudflare.com/client/v4"
FIXED_NS_RECORDS=("v" "vs" "s" "ss" "t" "ts")

trap 'echo; echo "❌ Error on line $LINENO. Script stopped."; exit 1' ERR

print_header() {
  clear 2>/dev/null || true
  echo "============================================================"
  echo "  Cloudflare Global API Key Auto Parking"
  echo "============================================================"
  echo
}

need_command() {
  command -v "$1" >/dev/null 2>&1
}

install_dependencies() {
  local missing=()

  need_command curl || missing+=("curl")
  need_command jq || missing+=("jq")

  if [[ ${#missing[@]} -eq 0 ]]; then
    return 0
  fi

  echo "Required packages are missing: ${missing[*]}"
  echo "Installing dependencies..."
  echo

  if [[ $EUID -eq 0 ]]; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y "${missing[@]}"
  elif need_command sudo; then
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${missing[@]}"
  else
    echo "❌ sudo is not available. Please install manually:"
    echo "apt-get update && apt-get install -y ${missing[*]}"
    exit 1
  fi
}

trim() {
  local s="${1:-}"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

normalize_domain() {
  local d
  d="$(trim "${1:-}")"
  d="$(printf '%s' "$d" \
    | sed -E 's#^https?://##I; s#/.*$##; s/[[:space:]]//g; s/\.$//' \
    | tr '[:upper:]' '[:lower:]')"
  printf '%s' "$d"
}

urlencode() {
  jq -rn --arg v "$1" '$v|@uri'
}

read_required() {
  local prompt="$1"
  local value="${2:-}"
  value="$(trim "$value")"
  if [[ -n "$value" ]]; then
    printf '%s' "$value"
    return 0
  fi
  echo "❌ Required value missing: ${prompt}" >&2
  return 1
}

read_secret_required() {
  local prompt="$1"
  local value="${2:-}"
  value="$(trim "$value")"
  if [[ -n "$value" ]]; then
    printf '%s' "$value"
    return 0
  fi
  echo "❌ Required secret missing: ${prompt}" >&2
  return 1
}

is_ipv4() {
  local ip="${1:-}"
  [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1

  local o1 o2 o3 o4 o
  IFS='.' read -r o1 o2 o3 o4 <<< "$ip"

  for o in "$o1" "$o2" "$o3" "$o4"; do
    [[ "$o" =~ ^[0-9]+$ ]] || return 1
    [[ "$o" -ge 0 && "$o" -le 255 ]] || return 1
  done
}

valid_email_basic() {
  [[ "${1:-}" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]]
}

valid_root_domain() {
  local d="${1:-}"
  [[ "$d" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$ ]]
}

fqdn_for_record() {
  local short_name="$1"
  local domain="$2"

  if [[ "$short_name" == "@" ]]; then
    printf '%s' "$domain"
  else
    printf '%s.%s' "$short_name" "$domain"
  fi
}

cf_api() {
  local method="$1"
  local endpoint="$2"
  local data="${3:-}"
  local tmp http_code body success errors

  tmp="$(mktemp)"

  if [[ -n "$data" ]]; then
    http_code="$(
      curl -sS -o "$tmp" -w "%{http_code}" \
        -X "$method" "$API_BASE$endpoint" \
        -H "X-Auth-Email: $CF_EMAIL" \
        -H "X-Auth-Key: $CF_GLOBAL_API_KEY" \
        -H "Content-Type: application/json" \
        --data "$data"
    )"
  else
    http_code="$(
      curl -sS -o "$tmp" -w "%{http_code}" \
        -X "$method" "$API_BASE$endpoint" \
        -H "X-Auth-Email: $CF_EMAIL" \
        -H "X-Auth-Key: $CF_GLOBAL_API_KEY" \
        -H "Content-Type: application/json"
    )"
  fi

  body="$(cat "$tmp")"
  rm -f "$tmp"

  if ! printf '%s' "$body" | jq empty >/dev/null 2>&1; then
    echo "❌ Non-JSON response from Cloudflare. HTTP status: $http_code"
    echo "$body"
    return 1
  fi

  success="$(printf '%s' "$body" | jq -r '.success // false')"

  if [[ "$success" != "true" ]]; then
    echo "❌ Cloudflare API request failed. HTTP status: $http_code"
    errors="$(printf '%s' "$body" | jq -r '.errors[]? | "- Code: \(.code) | Message: \(.message)"')"
    if [[ -n "$errors" ]]; then
      echo "$errors"
    else
      printf '%s' "$body" | jq .
    fi
    return 1
  fi

  printf '%s' "$body"
}

verify_global_api_key() {
  echo "Verifying Cloudflare Global API Key..."
  cf_api "GET" "/user" >/dev/null
  echo "✅ Global API Key verified."
  echo
}

get_zone_by_name() {
  local domain="$1"
  local encoded_domain encoded_account
  encoded_domain="$(urlencode "$domain")"
  encoded_account="$(urlencode "$CF_ACCOUNT_ID")"
  cf_api "GET" "/zones?name=${encoded_domain}&account.id=${encoded_account}&per_page=50"
}

create_zone() {
  local domain="$1"
  local payload

  payload="$(
    jq -n \
      --arg account_id "$CF_ACCOUNT_ID" \
      --arg domain "$domain" \
      '{account: {id: $account_id}, name: $domain, type: "full"}'
  )"

  cf_api "POST" "/zones" "$payload"
}

get_zone_details() {
  local zone_id="$1"
  cf_api "GET" "/zones/${zone_id}"
}

create_or_get_zone() {
  local domain="$1"
  local lookup count zone_id created

  lookup="$(get_zone_by_name "$domain")"
  count="$(printf '%s' "$lookup" | jq -r '.result_info.count // 0')"

  if [[ "$count" -gt 0 ]]; then
    zone_id="$(printf '%s' "$lookup" | jq -r '.result[0].id')"
    echo "ℹ️  Zone already exists. Using existing zone: $domain" >&2
    get_zone_details "$zone_id"
    return 0
  fi

  echo "Creating Cloudflare zone: $domain" >&2
  created="$(create_zone "$domain")"
  printf '%s' "$created"
}

print_cloudflare_name_servers() {
  local zone_json="$1"
  local ns_count

  ns_count="$(printf '%s' "$zone_json" | jq -r '.result.name_servers | length')"

  echo
  echo "============================================================"
  echo "Cloudflare Name Servers"
  echo "Set these name servers at your domain registrar:"
  echo "============================================================"

  if [[ "$ns_count" -gt 0 ]]; then
    printf '%s' "$zone_json" | jq -r '.result.name_servers[] | " - " + .'
  else
    echo "⚠️  No name servers returned yet. Check the zone in Cloudflare dashboard."
  fi

  echo "============================================================"
  echo
}

find_record_id() {
  local zone_id="$1"
  local type="$2"
  local name="$3"
  local encoded_name response

  encoded_name="$(urlencode "$name")"
  response="$(cf_api "GET" "/zones/${zone_id}/dns_records?type=${type}&name=${encoded_name}&per_page=100")"

  printf '%s' "$response" | jq -r '.result[0].id // empty'
}

upsert_a_record() {
  local zone_id="$1"
  local name="$2"
  local ip="$3"
  local record_id payload action response

  payload="$(
    jq -n \
      --arg name "$name" \
      --arg content "$ip" \
      '{
        type: "A",
        name: $name,
        content: $content,
        ttl: 1,
        proxied: false,
        comment: "Created/updated by Cloudflare Global API Key auto parking script"
      }'
  )"

  record_id="$(find_record_id "$zone_id" "A" "$name")"

  if [[ -n "$record_id" ]]; then
    response="$(cf_api "PUT" "/zones/${zone_id}/dns_records/${record_id}" "$payload")"
    action="Updated"
  else
    response="$(cf_api "POST" "/zones/${zone_id}/dns_records" "$payload")"
    action="Created"
  fi

  record_id="$(printf '%s' "$response" | jq -r '.result.id')"
  echo "✅ ${action} A record: ${name} -> ${ip} | proxied=false | id=${record_id}"
}

upsert_ns_record() {
  local zone_id="$1"
  local name="$2"
  local target="$3"
  local record_id payload action response

  payload="$(
    jq -n \
      --arg name "$name" \
      --arg content "$target" \
      '{
        type: "NS",
        name: $name,
        content: $content,
        ttl: 1,
        comment: "Created/updated by Cloudflare Global API Key auto parking script"
      }'
  )"

  record_id="$(find_record_id "$zone_id" "NS" "$name")"

  if [[ -n "$record_id" ]]; then
    response="$(cf_api "PUT" "/zones/${zone_id}/dns_records/${record_id}" "$payload")"
    action="Updated"
  else
    response="$(cf_api "POST" "/zones/${zone_id}/dns_records" "$payload")"
    action="Created"
  fi

  record_id="$(printf '%s' "$response" | jq -r '.result.id')"
  echo "✅ ${action} NS record: ${name} -> ${target} | id=${record_id}"
}

load_inputs() {
  CF_DOMAIN="${CF_DOMAIN:-${1:-}}"
  CF_SERVER_IPV4="${CF_SERVER_IPV4:-${2:-}}"
  CF_ACCOUNT_ID="${CF_ACCOUNT_ID:-${3:-}}"
  CF_EMAIL="${CF_EMAIL:-${4:-}}"
  CF_GLOBAL_API_KEY="${CF_GLOBAL_API_KEY:-${5:-}}"

  CF_DOMAIN="$(normalize_domain "$CF_DOMAIN")"
  CF_SERVER_IPV4="$(trim "$CF_SERVER_IPV4")"
  CF_ACCOUNT_ID="$(trim "$CF_ACCOUNT_ID")"
  CF_EMAIL="$(trim "$CF_EMAIL")"
  CF_GLOBAL_API_KEY="$(trim "$CF_GLOBAL_API_KEY")"

  if [[ -z "$CF_DOMAIN" ]]; then
    echo "❌ Required value missing: CF_DOMAIN"
    exit 1
  fi
  if ! valid_root_domain "$CF_DOMAIN"; then
    echo "❌ Invalid domain: $CF_DOMAIN"
    echo "Example of valid domain: amirab.sbs"
    exit 1
  fi

  if [[ -z "$CF_SERVER_IPV4" ]]; then
    echo "❌ Required value missing: CF_SERVER_IPV4"
    exit 1
  fi
  if ! is_ipv4 "$CF_SERVER_IPV4"; then
    echo "❌ Invalid IPv4 address: $CF_SERVER_IPV4"
    echo "Example of valid IPv4: 192.0.2.10"
    exit 1
  fi

  if [[ -z "$CF_ACCOUNT_ID" ]]; then
    echo "❌ Required value missing: CF_ACCOUNT_ID"
    exit 1
  fi

  if [[ -z "$CF_EMAIL" ]]; then
    echo "❌ Required value missing: CF_EMAIL"
    exit 1
  fi
  if ! valid_email_basic "$CF_EMAIL"; then
    echo "❌ Invalid Cloudflare email: $CF_EMAIL"
    echo "You entered a domain or another value where an email was required."
    echo "Example: your-email@example.com"
    exit 1
  fi

  if [[ -z "$CF_GLOBAL_API_KEY" ]]; then
    echo "❌ Required value missing: CF_GLOBAL_API_KEY"
    exit 1
  fi
}

main() {
  print_header
  install_dependencies

  echo "This script uses Cloudflare Global API Key authentication."
  echo "Input order is now: domain -> IP -> account ID -> email -> global API key."
  echo

  load_inputs "$@"

  local zone_json zone_id root_a ns_a ns_target item ns_record_name

  echo
  echo "Input summary:"
  echo " - Domain: $CF_DOMAIN"
  echo " - IPv4: $CF_SERVER_IPV4"
  echo " - Account ID: $CF_ACCOUNT_ID"
  echo " - Email: $CF_EMAIL"
  echo

  verify_global_api_key

  zone_json="$(create_or_get_zone "$CF_DOMAIN")"
  zone_id="$(printf '%s' "$zone_json" | jq -r '.result.id')"

  echo "✅ Zone is ready: $CF_DOMAIN"
  echo "Zone ID: $zone_id"

  print_cloudflare_name_servers "$zone_json"

  root_a="$(fqdn_for_record "@" "$CF_DOMAIN")"
  ns_a="$(fqdn_for_record "ns" "$CF_DOMAIN")"
  ns_target="ns.${CF_DOMAIN}"

  echo "Creating/updating fixed A records with proxy OFF..."
  upsert_a_record "$zone_id" "$root_a" "$CF_SERVER_IPV4"
  upsert_a_record "$zone_id" "$ns_a" "$CF_SERVER_IPV4"

  echo
  echo "Creating/updating fixed NS records..."
  for item in "${FIXED_NS_RECORDS[@]}"; do
    ns_record_name="$(fqdn_for_record "$item" "$CF_DOMAIN")"
    upsert_ns_record "$zone_id" "$ns_record_name" "$ns_target"
  done

  echo
  echo "============================================================"
  echo "Done."
  echo "============================================================"
  echo "Domain: $CF_DOMAIN"
  echo
  echo "A records:"
  echo " - ${CF_DOMAIN}    -> ${CF_SERVER_IPV4} | proxy OFF"
  echo " - ns.${CF_DOMAIN} -> ${CF_SERVER_IPV4} | proxy OFF"
  echo
  echo "NS records:"
  for item in "${FIXED_NS_RECORDS[@]}"; do
    echo " - ${item}.${CF_DOMAIN} -> ns.${CF_DOMAIN}"
  done
  echo
  echo "Next step:"
  echo "Set the Cloudflare name servers shown above at your domain registrar."
  echo "============================================================"
}

main "$@"
echo "__IRANUX_REACHED_END_V1__"
exit 0
