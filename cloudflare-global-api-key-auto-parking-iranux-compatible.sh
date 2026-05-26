#!/usr/bin/env bash

: <<'IRANUX_METADATA'
{
  "standard": {
    "name": "iranux-script-metadata",
    "schema_version": "1.0"
  },
  "script": {
    "id": "cloudflare-global-api-key-auto-parking",
    "name": "Cloudflare Global API Key Auto Parking",
    "version": "1.0.0",
    "description": "Adds or reuses a Cloudflare full zone using Global API Key authentication, prints Cloudflare-assigned nameservers, creates or updates A records for root and ns with proxy disabled, and creates or updates fixed NS records for v, vs, s, ss, t, and ts."
  },
  "risk": {
    "level": "high"
  },
  "requirements": {
    "requires_root": false,
    "requires_internet": true,
    "supported_os": ["ubuntu", "debian"],
    "required_commands": ["curl", "jq"]
  }
}
IRANUX_METADATA

: <<'IRANUX_PARAM'
{
  "name": "cf_email",
  "label": "Cloudflare Account Email",
  "description": "Cloudflare account email used with Global API Key authentication headers.",
  "type": "email",
  "required": true,
  "example": "admin@example.com",
  "group": "Cloudflare Credentials"
}
IRANUX_PARAM

: <<'IRANUX_PARAM'
{
  "name": "cf_global_api_key",
  "label": "Cloudflare Global API Key",
  "description": "Cloudflare Global API Key used as X-Auth-Key. This is highly sensitive and should not be logged or displayed.",
  "type": "secret",
  "required": true,
  "sensitive": true,
  "group": "Cloudflare Credentials"
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
  "name": "domain",
  "label": "Domain",
  "description": "Root domain to add or manage in Cloudflare, for example example.com. URLs are normalized to the root hostname by the script.",
  "type": "domain",
  "required": true,
  "example": "example.com",
  "group": "DNS Settings"
}
IRANUX_PARAM

: <<'IRANUX_PARAM'
{
  "name": "user_ip",
  "label": "Server IPv4 Address",
  "description": "IPv4 address used for the root A record and ns A record.",
  "type": "ipv4",
  "required": true,
  "example": "192.0.2.10",
  "group": "DNS Settings"
}
IRANUX_PARAM

set -Eeuo pipefail

# Cloudflare Global API Key Auto Parking Script
# Target OS: Ubuntu/Debian
#
# This script uses Cloudflare Global API Key authentication:
#   X-Auth-Email: <Cloudflare account email>
#   X-Auth-Key:   <Cloudflare Global API Key>
#
# Inputs:
#   1) Cloudflare account email
#   2) Cloudflare Global API Key
#   3) Cloudflare Account ID
#   4) Domain
#   5) Server IPv4
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
  clear || true
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

find_record_id() {
  local zone_id="$1"
  local type="$2"
  local name="$3"
  local encoded_name response

  encoded_name="$(urlencode "$name")"
  response="$(cf_api "GET" "/zones/${zone_id}/dns_records?type=${type}&name=${encoded_name}&per_page=100")"

  printf '%s' "$response" | jq -r '.result[0].id // empty'
}

delete_extra_records_same_name_type() {
  local zone_id="$1"
  local type="$2"
  local name="$3"
  local keep_id="$4"
  local encoded_name response ids id

  encoded_name="$(urlencode "$name")"
  response="$(cf_api "GET" "/zones/${zone_id}/dns_records?type=${type}&name=${encoded_name}&per_page=100")"
  ids="$(printf '%s' "$response" | jq -r --arg keep "$keep_id" '.result[]?.id | select(. != $keep)')"

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
  delete_extra_records_same_name_type "$zone_id" "A" "$name" "$record_id"

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
  delete_extra_records_same_name_type "$zone_id" "NS" "$name" "$record_id"

  echo "✅ ${action} NS record: ${name} -> ${target} | id=${record_id}"
}

main() {
  print_header
  install_dependencies

  echo "This version uses Cloudflare Global API Key authentication."
  echo "You need:"
  echo " - Cloudflare account email"
  echo " - Cloudflare Global API Key"
  echo " - Cloudflare Account ID"
  echo " - Domain"
  echo " - Server IPv4 address"
  echo

  CF_EMAIL="$(read_required "Cloudflare account email" "${CF_EMAIL:-}")"
  if ! valid_email_basic "$CF_EMAIL"; then
    echo "❌ Please provide a valid Cloudflare account email address."
    exit 1
  fi

  CF_GLOBAL_API_KEY="$(trim "${CF_GLOBAL_API_KEY:-}")"

  if [[ -z "$CF_GLOBAL_API_KEY" ]]; then
    echo "❌ Global API Key cannot be empty."
    exit 1
  fi

  CF_ACCOUNT_ID="$(read_required "Cloudflare Account ID" "${CF_ACCOUNT_ID:-}")"

  local DOMAIN USER_IP ZONE_JSON ZONE_ID ROOT_A NS_A NS_TARGET item ns_record_name

  DOMAIN="$(normalize_domain "${DOMAIN:-}")"
  if ! valid_root_domain "$DOMAIN"; then
    echo "❌ Please provide a valid root domain, e.g. example.com"
    exit 1
  fi

  USER_IP="$(trim "${USER_IP:-}")"
  if ! is_ipv4 "$USER_IP"; then
    echo "❌ Please provide a valid IPv4 address, e.g. 192.0.2.10"
    exit 1
  fi

  echo
  verify_global_api_key

  ZONE_JSON="$(create_or_get_zone "$DOMAIN")"
  ZONE_ID="$(printf '%s' "$ZONE_JSON" | jq -r '.result.id')"

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
