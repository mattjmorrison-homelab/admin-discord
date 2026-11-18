#!/usr/bin/env bash
# Writes every entry in webhook_openbao_paths (tofu.yml's apply job, after
# `tofu apply`) into its OpenBao KV path, using the matching URL from
# webhook_urls. Both come from a single "output-shaped" JSON file produced
# by `tofu output -json` with no output name given -- each top-level key is
# an output name, with its value nested under .<name>.value (contrast
# validate-webhook-grants.sh's "plan-shaped" `tofu show -json` input, where
# outputs live under .planned_values.outputs.<name>.value).
#
# Usage: write-webhook-secrets.sh <outputs.json>
# Requires VAULT_ADDR in the environment, plus the GitHub-OIDC env (see
# scripts/lib/vault-oidc-login.sh) to log in for the write.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/vault-oidc-login.sh
source "$SCRIPT_DIR/lib/vault-oidc-login.sh"

OUTPUTS_FILE="${1:?usage: write-webhook-secrets.sh <outputs.json>}"
: "${VAULT_ADDR:?VAULT_ADDR must be set}"

WEBHOOKS_TOKEN=$(vault_oidc_login admin-discord-webhooks-oidc)

WEBHOOK_URLS=$(jq -c '.webhook_urls.value' "$OUTPUTS_FILE")
WEBHOOK_PATHS=$(jq -c '.webhook_openbao_paths.value' "$OUTPUTS_FILE")

jq -r 'keys[]' <<< "$WEBHOOK_PATHS" | while IFS= read -r key; do
  value=$(jq -r --arg k "$key" '.[$k]' <<< "$WEBHOOK_URLS")
  path_suffix=$(jq -r --arg k "$key" '.[$k]' <<< "$WEBHOOK_PATHS")
  curl -sf -X POST -H "X-Vault-Token: $WEBHOOKS_TOKEN" \
    -d "$(jq -nc --arg value "$value" '{data: {value: $value}}')" \
    "$VAULT_ADDR/v1/kv/data/homelab/$path_suffix" > /dev/null
done
