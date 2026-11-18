#!/usr/bin/env bash
# Shared GitHub-OIDC -> OpenBao jwt-auth login flow, meant to be sourced
# (not executed) by scripts that need a Vault token. ACTIONS_ID_TOKEN_REQUEST_TOKEN
# and ACTIONS_ID_TOKEN_REQUEST_URL are already present in the environment of
# any step in a job with `permissions: id-token: write` -- no workflow YAML
# needs to fetch or pass them.
#
# Usage: source scripts/lib/vault-oidc-login.sh
#        token=$(vault_oidc_login <vault-role>)
# Requires VAULT_ADDR, ACTIONS_ID_TOKEN_REQUEST_TOKEN, ACTIONS_ID_TOKEN_REQUEST_URL
# in the environment. Prints the resulting Vault client token on stdout and
# masks it in the GitHub Actions log.
set -euo pipefail

vault_oidc_login() {
  local role="${1:?usage: vault_oidc_login <vault-role>}"
  : "${VAULT_ADDR:?VAULT_ADDR must be set}"
  : "${ACTIONS_ID_TOKEN_REQUEST_TOKEN:?ACTIONS_ID_TOKEN_REQUEST_TOKEN must be set}"
  : "${ACTIONS_ID_TOKEN_REQUEST_URL:?ACTIONS_ID_TOKEN_REQUEST_URL must be set}"

  local gh_oidc_token
  gh_oidc_token=$(curl -sf -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
    "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=openbao" | jq -r '.value')

  local client_token
  client_token=$(curl -sf -X POST "$VAULT_ADDR/v1/auth/jwt/login" \
    -d "$(jq -nc --arg jwt "$gh_oidc_token" --arg role "$role" '{jwt: $jwt, role: $role}')" \
    | jq -r '.auth.client_token')

  echo "::add-mask::$client_token" >&2
  printf '%s' "$client_token"
}
