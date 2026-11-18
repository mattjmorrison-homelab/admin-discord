#!/usr/bin/env bats

setup() {
  export PATH="$BATS_TEST_DIRNAME/mocks:$PATH"
  export CAPTURE_DIR="$BATS_TEST_TMPDIR"
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/validate-webhook-grants.sh"
  export VAULT_ADDR="http://vault.test"
  export WEBHOOKS_TOKEN="fake-webhooks-token"

  PATHS_FILE="$BATS_TEST_TMPDIR/webhook_openbao_paths.json"
}

@test "fails when the webhook_openbao_paths.json argument is missing" {
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage:"* ]]
}

@test "fails when VAULT_ADDR is unset" {
  unset VAULT_ADDR
  echo '{}' > "$PATHS_FILE"
  run bash "$SCRIPT" "$PATHS_FILE"
  [ "$status" -ne 0 ]
  [[ "$output" == *"VAULT_ADDR"* ]]
}

@test "fails when WEBHOOKS_TOKEN is unset" {
  unset WEBHOOKS_TOKEN
  echo '{}' > "$PATHS_FILE"
  run bash "$SCRIPT" "$PATHS_FILE"
  [ "$status" -ne 0 ]
  [[ "$output" == *"WEBHOOKS_TOKEN"* ]]
}

@test "passes when every path has both create and update" {
  echo '{"argocd": "k8s-argocd/discord-webhook-url"}' > "$PATHS_FILE"
  export MOCK_CAPS_RESPONSE='{"capabilities": ["create", "update", "read"]}'

  run bash "$SCRIPT" "$PATHS_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" != *"::error::"* ]]
}

@test "fails and reports the path+key when create is missing" {
  echo '{"argocd": "k8s-argocd/discord-webhook-url"}' > "$PATHS_FILE"
  export MOCK_CAPS_RESPONSE='{"capabilities": ["update"]}'

  run bash "$SCRIPT" "$PATHS_FILE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing 'create'"* ]]
  [[ "$output" == *"kv/data/homelab/k8s-argocd/discord-webhook-url"* ]]
  [[ "$output" == *"webhooks.argocd.openbao_path"* ]]
}

@test "fails and reports the path+key when update is missing" {
  echo '{"argocd": "k8s-argocd/discord-webhook-url"}' > "$PATHS_FILE"
  export MOCK_CAPS_RESPONSE='{"capabilities": ["create"]}'

  run bash "$SCRIPT" "$PATHS_FILE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing 'update'"* ]]
}

@test "fails when capabilities is deny, none of create/update present" {
  echo '{"argocd": "k8s-argocd/discord-webhook-url"}' > "$PATHS_FILE"
  export MOCK_CAPS_RESPONSE='{"capabilities": ["deny"]}'

  run bash "$SCRIPT" "$PATHS_FILE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing 'create'"* ]]
  [[ "$output" == *"missing 'update'"* ]]
}

@test "checks every entry even when an earlier one is missing a grant, and fails overall" {
  echo '{"argocd": "k8s-argocd/discord-webhook-url", "uptime": "service/admin-discord/pi-health/uptime-webhook-url"}' > "$PATHS_FILE"
  export MOCK_CAPS_RESPONSE_1='{"capabilities": ["update"]}'
  export MOCK_CAPS_RESPONSE_2='{"capabilities": ["create", "update"]}'

  run bash "$SCRIPT" "$PATHS_FILE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"webhooks.argocd.openbao_path"* ]]
  [[ "$output" != *"webhooks.uptime.openbao_path"* ]]
  [ "$(cat "$CAPTURE_DIR/caps_call_count")" = "2" ]
}

@test "passes when every entry across multiple paths has both grants" {
  echo '{"argocd": "k8s-argocd/discord-webhook-url", "uptime": "service/admin-discord/pi-health/uptime-webhook-url"}' > "$PATHS_FILE"
  export MOCK_CAPS_RESPONSE='{"capabilities": ["create", "update"]}'

  run bash "$SCRIPT" "$PATHS_FILE"
  [ "$status" -eq 0 ]
  [ "$(cat "$CAPTURE_DIR/caps_call_count")" = "2" ]
}

@test "passes when webhook_openbao_paths.json is empty" {
  echo '{}' > "$PATHS_FILE"

  run bash "$SCRIPT" "$PATHS_FILE"
  [ "$status" -eq 0 ]
}
