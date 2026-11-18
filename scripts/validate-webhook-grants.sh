#!/usr/bin/env bash
# Verifies WEBHOOKS_TOKEN has create+update capability on every path in
# webhook_openbao_paths (tofu.yml's check job, derived from the plan's
# output so a brand-new webhooks.* entry is covered before it's ever
# applied). Catches the pi-health webhook bug -- a new consumer added to
# locals.tf with no matching OpenBao write grant -- before merge.
#
# Usage: validate-webhook-grants.sh <webhook_openbao_paths.json>
# Requires VAULT_ADDR and WEBHOOKS_TOKEN in the environment.
set -euo pipefail

PATHS_FILE="${1:?usage: validate-webhook-grants.sh <webhook_openbao_paths.json>}"
: "${VAULT_ADDR:?VAULT_ADDR must be set}"
: "${WEBHOOKS_TOKEN:?WEBHOOKS_TOKEN must be set}"

missing=0

while IFS='=' read -r key suffix; do
  [ -z "$key" ] && continue
  vault_path="kv/data/homelab/$suffix"
  caps=$(curl -sf -X POST -H "X-Vault-Token: $WEBHOOKS_TOKEN" \
    -d "$(jq -nc --arg token "$WEBHOOKS_TOKEN" --arg path "$vault_path" '{token: $token, path: $path}')" \
    "$VAULT_ADDR/v1/sys/capabilities-self" | jq -r '.capabilities | join(",")')

  case ",$caps," in
    *,create,*) ;;
    *) echo "::error::OpenBao grant missing 'create' on $vault_path (webhooks.$key.openbao_path) -- see admin-openbao's admin-discord-webhooks policy"
       missing=1 ;;
  esac
  case ",$caps," in
    *,update,*) ;;
    *) echo "::error::OpenBao grant missing 'update' on $vault_path (webhooks.$key.openbao_path) -- see admin-openbao's admin-discord-webhooks policy"
       missing=1 ;;
  esac
done < <(jq -r 'to_entries[] | "\(.key)=\(.value)"' "$PATHS_FILE")

if [ "$missing" -eq 1 ]; then
  echo "::error::One or more webhooks.* entries are missing their OpenBao create/update grant -- the apply job's write-back would silently fail for them. Fix in admin-openbao's admin-discord-webhooks policy before merging."
  exit 1
fi
