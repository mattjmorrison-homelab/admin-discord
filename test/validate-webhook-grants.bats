#!/usr/bin/env bats

setup() {
  export PATH="$BATS_TEST_DIRNAME/mocks:$PATH"
  export CAPTURE_DIR="$BATS_TEST_TMPDIR"
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/validate-webhook-grants.sh"
  export VAULT_ADDR="http://vault.test"
  export ACTIONS_ID_TOKEN_REQUEST_TOKEN="fake-request-token"
  export ACTIONS_ID_TOKEN_REQUEST_URL="https://actions.test/oidc?foo=bar"

  PLAN_FILE="$BATS_TEST_TMPDIR/tfplan.json"
}

@test "fails when the tfplan.json argument is missing" {
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage:"* ]]
}

@test "fails when VAULT_ADDR is unset" {
  unset VAULT_ADDR
  echo '{"planned_values": {"outputs": {"webhook_openbao_paths": {"value": []}}}}' > "$PLAN_FILE"
  run bash "$SCRIPT" "$PLAN_FILE"
  [ "$status" -ne 0 ]
  [[ "$output" == *"VAULT_ADDR"* ]]
}

@test "fails when ACTIONS_ID_TOKEN_REQUEST_TOKEN is unset" {
  unset ACTIONS_ID_TOKEN_REQUEST_TOKEN
  echo '{"planned_values": {"outputs": {"webhook_openbao_paths": {"value": []}}}}' > "$PLAN_FILE"
  run bash "$SCRIPT" "$PLAN_FILE"
  [ "$status" -ne 0 ]
  [[ "$output" == *"ACTIONS_ID_TOKEN_REQUEST_TOKEN"* ]]
}

@test "fails when ACTIONS_ID_TOKEN_REQUEST_URL is unset" {
  unset ACTIONS_ID_TOKEN_REQUEST_URL
  echo '{"planned_values": {"outputs": {"webhook_openbao_paths": {"value": []}}}}' > "$PLAN_FILE"
  run bash "$SCRIPT" "$PLAN_FILE"
  [ "$status" -ne 0 ]
  [[ "$output" == *"ACTIONS_ID_TOKEN_REQUEST_URL"* ]]
}

@test "logs in via GitHub OIDC with the webhooks-write role before checking capabilities" {
  echo '{"planned_values": {"outputs": {"webhook_openbao_paths": {"value": [{"key": "argocd", "path": "service/admin-discord/k8s-argocd/discord-webhook-url"}]}}}}' > "$PLAN_FILE"
  export MOCK_CAPS_RESPONSE='{"capabilities": ["create", "update"]}'

  run bash "$SCRIPT" "$PLAN_FILE"
  [ "$status" -eq 0 ]

  grep -q "audience=openbao" "$CAPTURE_DIR/curl.calls"
  grep -q "auth/jwt/login" "$CAPTURE_DIR/curl.calls"
  [ "$(jq -r '.role' "$CAPTURE_DIR/login.log")" = "admin-discord-webhooks-oidc" ]
  [ "$(jq -r '.jwt' "$CAPTURE_DIR/login.log")" = "fake-oidc-jwt" ]
}

@test "passes when every path has both create and update, extracted from the plan JSON" {
  echo '{"planned_values": {"outputs": {"webhook_openbao_paths": {"value": [{"key": "argocd", "path": "service/admin-discord/k8s-argocd/discord-webhook-url"}]}}}}' > "$PLAN_FILE"
  export MOCK_CAPS_RESPONSE='{"capabilities": ["create", "update", "read"]}'

  run bash "$SCRIPT" "$PLAN_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" != *"::error::"* ]]
}

@test "fails and reports the path+key when create is missing" {
  echo '{"planned_values": {"outputs": {"webhook_openbao_paths": {"value": [{"key": "argocd", "path": "service/admin-discord/k8s-argocd/discord-webhook-url"}]}}}}' > "$PLAN_FILE"
  export MOCK_CAPS_RESPONSE='{"capabilities": ["update"]}'

  run bash "$SCRIPT" "$PLAN_FILE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing 'create'"* ]]
  [[ "$output" == *"kv/data/homelab/service/admin-discord/k8s-argocd/discord-webhook-url"* ]]
  [[ "$output" == *"webhooks.argocd.openbao_paths"* ]]
}

@test "fails and reports the path+key when update is missing" {
  echo '{"planned_values": {"outputs": {"webhook_openbao_paths": {"value": [{"key": "argocd", "path": "service/admin-discord/k8s-argocd/discord-webhook-url"}]}}}}' > "$PLAN_FILE"
  export MOCK_CAPS_RESPONSE='{"capabilities": ["create"]}'

  run bash "$SCRIPT" "$PLAN_FILE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing 'update'"* ]]
}

@test "fails when capabilities is deny, none of create/update present" {
  echo '{"planned_values": {"outputs": {"webhook_openbao_paths": {"value": [{"key": "argocd", "path": "service/admin-discord/k8s-argocd/discord-webhook-url"}]}}}}' > "$PLAN_FILE"
  export MOCK_CAPS_RESPONSE='{"capabilities": ["deny"]}'

  run bash "$SCRIPT" "$PLAN_FILE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing 'create'"* ]]
  [[ "$output" == *"missing 'update'"* ]]
}

@test "checks every entry even when an earlier one is missing a grant, and fails overall" {
  echo '{"planned_values": {"outputs": {"webhook_openbao_paths": {"value": [
    {"key": "argocd", "path": "service/admin-discord/k8s-argocd/discord-webhook-url"},
    {"key": "uptime", "path": "service/admin-discord/pi-health/uptime-webhook-url"}
  ]}}}}' > "$PLAN_FILE"
  export MOCK_CAPS_RESPONSE_1='{"capabilities": ["update"]}'
  export MOCK_CAPS_RESPONSE_2='{"capabilities": ["create", "update"]}'

  run bash "$SCRIPT" "$PLAN_FILE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"webhooks.argocd.openbao_paths"* ]]
  [[ "$output" != *"webhooks.uptime.openbao_paths"* ]]
  [ "$(cat "$CAPTURE_DIR/caps_call_count")" = "2" ]
}

@test "passes when every entry across multiple paths has both grants" {
  echo '{"planned_values": {"outputs": {"webhook_openbao_paths": {"value": [
    {"key": "argocd", "path": "service/admin-discord/k8s-argocd/discord-webhook-url"},
    {"key": "uptime", "path": "service/admin-discord/pi-health/uptime-webhook-url"}
  ]}}}}' > "$PLAN_FILE"
  export MOCK_CAPS_RESPONSE='{"capabilities": ["create", "update"]}'

  run bash "$SCRIPT" "$PLAN_FILE"
  [ "$status" -eq 0 ]
  [ "$(cat "$CAPTURE_DIR/caps_call_count")" = "2" ]
}

@test "checks both paths independently when one webhook key has more than one path" {
  echo '{"planned_values": {"outputs": {"webhook_openbao_paths": {"value": [
    {"key": "downtime", "path": "service/admin-discord/pi-health/downtime-webhook-url"},
    {"key": "downtime", "path": "service/admin-discord/k8s-alertmanager/downtime-webhook-url"}
  ]}}}}' > "$PLAN_FILE"
  export MOCK_CAPS_RESPONSE_1='{"capabilities": ["create", "update"]}'
  export MOCK_CAPS_RESPONSE_2='{"capabilities": ["update"]}'

  run bash "$SCRIPT" "$PLAN_FILE"
  [ "$status" -eq 1 ]
  [ "$(cat "$CAPTURE_DIR/caps_call_count")" = "2" ]
  [[ "$output" == *"missing 'create' on kv/data/homelab/service/admin-discord/k8s-alertmanager/downtime-webhook-url"* ]]
  [[ "$output" != *"pi-health/downtime-webhook-url"* ]]
}

@test "passes when webhook_openbao_paths is empty" {
  echo '{"planned_values": {"outputs": {"webhook_openbao_paths": {"value": []}}}}' > "$PLAN_FILE"

  run bash "$SCRIPT" "$PLAN_FILE"
  [ "$status" -eq 0 ]
}
