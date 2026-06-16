#!/usr/bin/env bash

: <<'IRANUX_METADATA'
{
  "standard": {
    "name": "iranux-script-metadata",
    "schema_version": "1.1"
  },
  "script": {
    "id": "cloudflare-api-token-auto-parking",
    "name": "Cloudflare API Token Auto Parking",
    "version": "1.0.0",
    "description": "Adds or reuses a Cloudflare full zone using Bearer API Token authentication, creates or updates fixed A and NS records, checks conflicting DNS records, and supports non-interactive Iranux inputs."
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
      "name": "cloud-outline"
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
  "name": "cf_api_token",
  "label": "Cloudflare API Token",
  "description": "Cloudflare API Token used as a Bearer token. Required permissions: Zone > Zone > Edit and Zone > DNS > Edit.",
  "type": "secret",
  "required": true,
  "sensitive": true,
  "group": "Cloudflare Credentials"
}
IRANUX_PARAM

set -Eeuo pipefail

# Cloudflare API Token Auto Parking Script
# Ubuntu/Debian compatible
#
# Authentication method:
#   Authorization: Bearer <Cloudflare API Token>
#
# Inputs:
#   1) Domain
#   2) Server IPv4 address
#   3) Cloudflare Account ID
#   4) Cloudflare API Token
#
# Actions:
#   - Adds/parks the domain as a Cloudflare full zone
#   - Prints Cloudflare-assigned name servers
#   - Creates/updates two A records with proxy OFF:
#       @  -> USER_IP
#       ns -> USER_IP
#   - Creates/updates six NS records:
#       v.domain.com  -> ns.domain.com
#       vs.domain.com -> ns.domain.com
#       s.domain.com  -> ns.domain.com
#       ss.domain.com -> ns.domain.com
#       t.domain.com  -> ns.domain.com
#       ts.domain.com -> ns.domain.com

API_BASE="https://api.cloudflare.com/client/v4"
FIXED_NS_RECORDS=("v" "vs" "s" "ss" "t" "ts")

trap 'echo; echo "❌ Error on line $LINENO. Script stopped."; exit 1' ERR

print_header() {
  clear || true
  echo "============================================================"
  echo "  Cloudflare API Token Auto Parking"
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

valid_root_domain() {
  local d="${1:-}"
  [[ "$d" == *.* && "$d" != .* && "$d" != *..* && "$d" != *"/"* ]]
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
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "$data"
    )"
  else
    http_code="$(
      curl -sS -o "$tmp" -w "%{http_code}" \
        -X "$method" "$API_BASE$endpoint" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
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

verify_api_token() {
  echo "Verifying Cloudflare API Token..."
  cf_api "GET" "/user/tokens/verify" >/dev/null
  echo "✅ API Token verified."
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
      '{
        account: {id: $account_id},
        name: $domain,
        type: "full",
        jump_start: false
      }'
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

list_records_by_name() {
  local zone_id="$1"
  local name="$2"
  local encoded_name
  encoded_name="$(urlencode "$name")"
  cf_api "GET" "/zones/${zone_id}/dns_records?name=${encoded_name}&per_page=100"
}

find_record_id() {
  local zone_id="$1"
  local type="$2"
  local name="$3"
  local response

  response="$(list_records_by_name "$zone_id" "$name")"

  printf '%s' "$response" | jq -r --arg type "$type" '.result[]? | select(.type == $type) | .id' | head -n 1
}

fail_if_conflicting_records_for_a() {
  local zone_id="$1"
  local name="$2"
  local response conflicts

  response="$(list_records_by_name "$zone_id" "$name")"
  conflicts="$(printf '%s' "$response" | jq -r '.result[]? | select(.type == "CNAME") | "- " + .type + " " + .name + " -> " + .content')"

  if [[ -n "$conflicts" ]]; then
    echo "❌ Cannot create/update A record for ${name} because a conflicting CNAME exists:"
    echo "$conflicts"
    echo "Delete the conflicting record manually, then run this script again."
    return 1
  fi
}

fail_if_conflicting_records_for_ns() {
  local zone_id="$1"
  local name="$2"
  local response conflicts

  response="$(list_records_by_name "$zone_id" "$name")"
  conflicts="$(printf '%s' "$response" | jq -r '.result[]? | select(.type != "NS") | "- " + .type + " " + .name + " -> " + .content')"

  if [[ -n "$conflicts" ]]; then
    echo "❌ Cannot create/update NS record for ${name} because another record type exists at the same name:"
    echo "$conflicts"
    echo "Cloudflare does not allow NS records on the same name as other record types."
    echo "Delete the conflicting record manually, then run this script again."
    return 1
  fi
}

delete_extra_records_same_name_type() {
  local zone_id="$1"
  local type="$2"
  local name="$3"
  local keep_id="$4"
  local response ids id

  response="$(list_records_by_name "$zone_id" "$name")"
  ids="$(printf '%s' "$response" | jq -r --arg type "$type" --arg keep "$keep_id" '.result[]? | select(.type == $type and .id != $keep) | .id')"

  if [[ -z "$ids" ]]; then
    return 0
  fi

  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    cf_api "DELETE" "/zones/${zone_id}/dns_records/${id}" >/dev/null
    echo "🧹 Deleted duplicate ${type} record for ${name}: ${id}"
  done <<< "$ids"
}

upsert_a_record() {
  local zone_id="$1"
  local name="$2"
  local ip="$3"
  local record_id payload action response

  fail_if_conflicting_records_for_a "$zone_id" "$name"

  payload="$(
    jq -n \
      --arg name "$name" \
      --arg content "$ip" \
      '{
        type: "A",
        name: $name,
        content: $content,
        ttl: 1,
        proxied: false
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
  delete_extra_records_same_name_type "$zone_id" "A" "$name" "$record_id"

  echo "✅ ${action} A record: ${name} -> ${ip} | proxied=false | id=${record_id}"
}

upsert_ns_record() {
  local zone_id="$1"
  local name="$2"
  local target="$3"
  local record_id payload action response

  fail_if_conflicting_records_for_ns "$zone_id" "$name"

  payload="$(
    jq -n \
      --arg name "$name" \
      --arg content "$target" \
      '{
        type: "NS",
        name: $name,
        content: $content,
        ttl: 1
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
  delete_extra_records_same_name_type "$zone_id" "NS" "$name" "$record_id"

  echo "✅ ${action} NS record: ${name} -> ${target} | id=${record_id}"
}

load_inputs() {
  # Accept both Iranux parameter names and Bash-style environment variable names.
  # This prevents mapping errors when the runner injects lowercase parameter names.
  DOMAIN="${CF_DOMAIN:-${cf_domain:-${DOMAIN:-${domain:-${1:-}}}}}"
  USER_IP="${CF_SERVER_IPV4:-${cf_server_ipv4:-${USER_IP:-${user_ip:-${2:-}}}}}"
  CF_ACCOUNT_ID="${CF_ACCOUNT_ID:-${cf_account_id:-${3:-}}}"
  CF_API_TOKEN="${CF_API_TOKEN:-${cf_api_token:-${4:-}}}"

  DOMAIN="$(normalize_domain "$DOMAIN")"
  USER_IP="$(trim "$USER_IP")"
  CF_ACCOUNT_ID="$(trim "$CF_ACCOUNT_ID")"
  CF_API_TOKEN="$(trim "$CF_API_TOKEN")"

  if [[ -z "$DOMAIN" ]]; then
    echo "❌ Required value missing: cf_domain / CF_DOMAIN / DOMAIN"
    exit 1
  fi
  if ! valid_root_domain "$DOMAIN"; then
    echo "❌ Invalid domain: $DOMAIN"
    echo "Example of valid domain: amirab.sbs"
    exit 1
  fi

  if [[ -z "$USER_IP" ]]; then
    echo "❌ Required value missing: cf_server_ipv4 / CF_SERVER_IPV4 / USER_IP"
    exit 1
  fi
  if ! is_ipv4 "$USER_IP"; then
    echo "❌ Invalid IPv4 address: $USER_IP"
    echo "Example of valid IPv4: 192.0.2.10"
    exit 1
  fi

  if [[ -z "$CF_ACCOUNT_ID" ]]; then
    echo "❌ Required value missing: cf_account_id / CF_ACCOUNT_ID"
    exit 1
  fi

  if [[ -z "$CF_API_TOKEN" ]]; then
    echo "❌ Required value missing: cf_api_token / CF_API_TOKEN"
    exit 1
  fi
}

main() {
  print_header
  install_dependencies

  echo "This version uses a Cloudflare API Token, not the Global API Key."
  echo "Required token permissions:"
  echo " - Zone > Zone > Edit"
  echo " - Zone > DNS  > Edit"
  echo

  local DOMAIN USER_IP CF_ACCOUNT_ID CF_API_TOKEN

  load_inputs "$@"

  echo
  verify_api_token

  local ZONE_JSON ZONE_ID ROOT_A NS_A NS_TARGET item ns_record_name

  ZONE_JSON="$(create_or_get_zone "$DOMAIN")"
  ZONE_ID="$(printf '%s' "$ZONE_JSON" | jq -r '.result.id')"

  if [[ -z "$ZONE_ID" || "$ZONE_ID" == "null" ]]; then
    echo "❌ Could not determine Zone ID."
    exit 1
  fi

  echo "✅ Zone is ready: $DOMAIN"
  echo "Zone ID: $ZONE_ID"

  print_cloudflare_name_servers "$ZONE_JSON"

  ROOT_A="$(fqdn_for_record "@" "$DOMAIN")"
  NS_A="$(fqdn_for_record "ns" "$DOMAIN")"
  NS_TARGET="ns.${DOMAIN}"

  echo "Creating/updating fixed A records with proxy OFF..."
  upsert_a_record "$ZONE_ID" "$ROOT_A" "$USER_IP"
  upsert_a_record "$ZONE_ID" "$NS_A" "$USER_IP"

  echo
  echo "Creating/updating fixed NS records..."
  for item in "${FIXED_NS_RECORDS[@]}"; do
    ns_record_name="$(fqdn_for_record "$item" "$DOMAIN")"
    upsert_ns_record "$ZONE_ID" "$ns_record_name" "$NS_TARGET"
  done

  echo
  echo "============================================================"
  echo "Done."
  echo "============================================================"
  echo "Domain: $DOMAIN"
  echo
  echo "A records:"
  echo " - ${DOMAIN}    -> ${USER_IP} | proxy OFF"
  echo " - ns.${DOMAIN} -> ${USER_IP} | proxy OFF"
  echo
  echo "NS records:"
  for item in "${FIXED_NS_RECORDS[@]}"; do
    echo " - ${item}.${DOMAIN} -> ns.${DOMAIN}"
  done
  echo
  echo "Next step:"
  echo "Set the Cloudflare name servers shown above at your domain registrar."
  echo "============================================================"
}

main "$@"
echo "__IRANUX_REACHED_END_V1__"
exit 0
