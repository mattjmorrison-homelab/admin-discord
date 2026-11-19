#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/vault-oidc-login.sh
source "$SCRIPT_DIR/lib/vault-oidc-login.sh"

OUTPUTS_FILE="${1:?usage: write-webhook-secrets.sh <outputs.json>}"
: "${VAULT_ADDR:?VAULT_ADDR must be set}"

WEBHOOKS_TOKEN=$(vault_oidc_login admin-discord-webhooks-oidc)

WEBHOOK_URLS=$(jq -c '.webhook_urls.value' "$OUTPUTS_FILE")
WEBHOOK_PATHS=$(jq -c '.webhook_openbao_paths.value' "$OUTPUTS_FILE")

jq -c '.[]' <<< "$WEBHOOK_PATHS" | while IFS= read -r entry; do
  key=$(jq -r '.key' <<< "$entry")
  path_suffix=$(jq -r '.path' <<< "$entry")
  value=$(jq -r --arg k "$key" '.[$k]' <<< "$WEBHOOK_URLS")
  curl -sf -X POST -H "X-Vault-Token: $WEBHOOKS_TOKEN" \
    -d "$(jq -nc --arg value "$value" '{data: {value: $value}}')" \
    "$VAULT_ADDR/v1/kv/data/homelab/$path_suffix" > /dev/null
done
