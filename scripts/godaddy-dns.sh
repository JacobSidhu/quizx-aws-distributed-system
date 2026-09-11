#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "Usage: $0 upsert|delete <zone> <type> <name> <data> [ttl]" >&2
  exit 2
}

[[ $# -ge 5 && $# -le 6 ]] || usage

action=$1
zone=${2%.}
record_type=${3^^}
record_name=${4%.}
record_data=${5%.}
ttl=${6:-600}
api_base_url=${GODADDY_API_BASE_URL:-https://api.godaddy.com}

[[ "$action" == "upsert" || "$action" == "delete" ]] || usage
[[ -n "${GO_DADDY_DNS_TOKEN:-}" ]] || {
  echo "GO_DADDY_DNS_TOKEN is required." >&2
  exit 1
}
[[ "$zone" =~ ^[A-Za-z0-9.-]+$ ]] || {
  echo "Invalid DNS zone: $zone" >&2
  exit 1
}
[[ "$record_type" =~ ^(A|AAAA|CNAME|MX|TXT|SRV|NS|CAA)$ ]] || {
  echo "Unsupported DNS record type: $record_type" >&2
  exit 1
}
[[ "$ttl" =~ ^[0-9]+$ ]] || {
  echo "TTL must be an integer." >&2
  exit 1
}

# ACM returns a fully-qualified name. GoDaddy expects a name relative to the
# managed zone, so "_token.api.example.com" becomes "_token.api".
if [[ "$record_name" == "$zone" ]]; then
  record_name="@"
elif [[ "$record_name" == *".$zone" ]]; then
  record_name=${record_name%."$zone"}
fi

auth_header="Authorization: Bearer ${GO_DADDY_DNS_TOKEN}"
records_url="${api_base_url}/v3/domains/zones/${zone}/dns-records"

response=$(curl --fail-with-body --silent --show-error --get "$records_url" \
  --header "$auth_header" \
  --header "Accept: application/json" \
  --data-urlencode "type=$record_type" \
  --data-urlencode "name=$record_name" \
  --data-urlencode "pageSize=100")

matching_count=$(jq --arg data "$record_data" \
  '[.items[]? | select((.data | rtrimstr(".")) == $data)] | length' \
  <<<"$response")

if [[ "$action" == "delete" ]]; then
  if [[ "$matching_count" == "0" ]]; then
    echo "GoDaddy $record_type record $record_name already absent or changed; nothing to delete."
    exit 0
  fi

  while IFS= read -r record_id; do
    curl --fail-with-body --silent --show-error --request DELETE \
      "${records_url}/${record_id}" \
      --header "$auth_header" \
      --header "Accept: application/json" \
      --output /dev/null
  done < <(jq --raw-output --arg data "$record_data" \
    '.items[]? | select((.data | rtrimstr(".")) == $data) | .recordId' \
    <<<"$response")

  echo "Deleted GoDaddy $record_type record $record_name from $zone."
  exit 0
fi

existing_count=$(jq '.items | length' <<<"$response")
if [[ "$existing_count" -gt 1 ]]; then
  echo "Refusing to modify $existing_count existing $record_type records named $record_name." >&2
  exit 1
fi

if [[ "$matching_count" != "0" ]]; then
  echo "GoDaddy $record_type record $record_name already has the requested value."
  exit 0
fi

payload=$(jq --null-input \
  --arg type "$record_type" \
  --arg name "$record_name" \
  --arg data "$record_data" \
  --argjson ttl "$ttl" \
  '{type: $type, name: $name, data: $data, ttl: $ttl}')

if [[ "$existing_count" == "0" ]]; then
  curl --fail-with-body --silent --show-error --request POST "$records_url" \
    --header "$auth_header" \
    --header "Accept: application/json" \
    --header "Content-Type: application/json" \
    --data "$payload" \
    --output /dev/null
  echo "Created GoDaddy $record_type record $record_name in $zone."
  exit 0
fi

record_id=$(jq --raw-output '.items[0].recordId' <<<"$response")
curl --fail-with-body --silent --show-error --request PUT \
  "${records_url}/${record_id}" \
  --header "$auth_header" \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --data "$payload" \
  --output /dev/null

echo "Updated GoDaddy $record_type record $record_name in $zone."
