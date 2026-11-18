#!/usr/bin/env bash
# Writes every entry in webhook_openbao_paths (tofu.yml's apply job, after
# `tofu apply`) into its OpenBao KV path, using the matching URL from
# webhook_urls. Both inputs are JSON objects keyed by the same webhook name
# (locals.tf's `webhooks` map keys) -- see outputs.tf.
#
# Usage: write-webhook-secrets.sh <webhook_urls.json> <webhook_openbao_paths.json>
# Requires VAULT_ADDR and WEBHOOKS_TOKEN in the environment.
set -euo pipefail

WEBHOOK_URLS_FILE="${1:?usage: write-webhook-secrets.sh <webhook_urls.json> <webhook_openbao_paths.json>}"
WEBHOOK_PATHS_FILE="${2:?usage: write-webhook-secrets.sh <webhook_urls.json> <webhook_openbao_paths.json>}"
: "${VAULT_ADDR:?VAULT_ADDR must be set}"
: "${WEBHOOKS_TOKEN:?WEBHOOKS_TOKEN must be set}"

jq -r 'keys[]' "$WEBHOOK_PATHS_FILE" | while IFS= read -r key; do
  value=$(jq -r --arg k "$key" '.[$k]' "$WEBHOOK_URLS_FILE")
  path_suffix=$(jq -r --arg k "$key" '.[$k]' "$WEBHOOK_PATHS_FILE")
  curl -sf -X POST -H "X-Vault-Token: $WEBHOOKS_TOKEN" \
    -d "$(jq -nc --arg value "$value" '{data: {value: $value}}')" \
    "$VAULT_ADDR/v1/kv/data/homelab/$path_suffix" > /dev/null
done
