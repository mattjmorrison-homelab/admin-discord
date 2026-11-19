#!/usr/bin/env bash
# Verifies the webhooks-write Vault role has create+update capability on
# every path in webhook_openbao_paths, before merge, so a new consumer
# with no matching OpenBao grant fails loudly here instead of silently
# at apply.
#
# Takes "plan-shaped" JSON from `tofu show -json tfplan` -- outputs live
# under .planned_values.outputs.<name>.value (contrast
# write-webhook-secrets.sh's "output-shaped" `tofu output -json`, where
# each output's value is directly under .<name>.value).
#
# webhook_openbao_paths.value is a flat list of {key, path} objects -- a
# webhook key (e.g. downtime) can appear more than once, each checked
# independently.
#
# Usage: validate-webhook-grants.sh <tfplan.json>
# Requires VAULT_ADDR, plus the GitHub-OIDC env (see
# scripts/lib/vault-oidc-login.sh).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/vault-oidc-login.sh
source "$SCRIPT_DIR/lib/vault-oidc-login.sh"

PLAN_FILE="${1:?usage: validate-webhook-grants.sh <tfplan.json>}"
: "${VAULT_ADDR:?VAULT_ADDR must be set}"

WEBHOOKS_TOKEN=$(vault_oidc_login admin-discord-webhooks-oidc)

PATHS_JSON=$(jq -c '.planned_values.outputs.webhook_openbao_paths.value' "$PLAN_FILE")

missing=0

while IFS= read -r entry; do
  [ -z "$entry" ] && continue
  key=$(jq -r '.key' <<< "$entry")
  suffix=$(jq -r '.path' <<< "$entry")
  vault_path="kv/data/homelab/$suffix"
  caps=$(curl -sf -X POST -H "X-Vault-Token: $WEBHOOKS_TOKEN" \
    -d "$(jq -nc --arg token "$WEBHOOKS_TOKEN" --arg path "$vault_path" '{token: $token, path: $path}')" \
    "$VAULT_ADDR/v1/sys/capabilities-self" | jq -r '.capabilities | join(",")')

  case ",$caps," in
    *,create,*) ;;
    *) echo "::error::OpenBao grant missing 'create' on $vault_path (webhooks.$key.openbao_paths) -- see admin-openbao's admin-discord-webhooks policy"
       missing=1 ;;
  esac
  case ",$caps," in
    *,update,*) ;;
    *) echo "::error::OpenBao grant missing 'update' on $vault_path (webhooks.$key.openbao_paths) -- see admin-openbao's admin-discord-webhooks policy"
       missing=1 ;;
  esac
done < <(jq -c '.[]' <<< "$PATHS_JSON")

if [ "$missing" -eq 1 ]; then
  echo "::error::One or more webhooks.* entries are missing their OpenBao create/update grant -- the apply job's write-back would silently fail for them. Fix in admin-openbao's admin-discord-webhooks policy before merging."
  exit 1
fi
