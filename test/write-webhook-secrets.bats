#!/usr/bin/env bats

setup() {
  export PATH="$BATS_TEST_DIRNAME/mocks:$PATH"
  export CAPTURE_DIR="$BATS_TEST_TMPDIR"
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/write-webhook-secrets.sh"
  export VAULT_ADDR="http://vault.test"
  export ACTIONS_ID_TOKEN_REQUEST_TOKEN="fake-request-token"
  export ACTIONS_ID_TOKEN_REQUEST_URL="https://actions.test/oidc?foo=bar"

  OUTPUTS_FILE="$BATS_TEST_TMPDIR/outputs.json"
}

@test "fails when the outputs.json argument is missing" {
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage:"* ]]
}

@test "fails when VAULT_ADDR is unset" {
  unset VAULT_ADDR
  echo '{"webhook_urls": {"value": {}}, "webhook_openbao_paths": {"value": []}}' > "$OUTPUTS_FILE"
  run bash "$SCRIPT" "$OUTPUTS_FILE"
  [ "$status" -ne 0 ]
  [[ "$output" == *"VAULT_ADDR"* ]]
}

@test "fails when ACTIONS_ID_TOKEN_REQUEST_TOKEN is unset" {
  unset ACTIONS_ID_TOKEN_REQUEST_TOKEN
  echo '{"webhook_urls": {"value": {}}, "webhook_openbao_paths": {"value": []}}' > "$OUTPUTS_FILE"
  run bash "$SCRIPT" "$OUTPUTS_FILE"
  [ "$status" -ne 0 ]
  [[ "$output" == *"ACTIONS_ID_TOKEN_REQUEST_TOKEN"* ]]
}

@test "fails when ACTIONS_ID_TOKEN_REQUEST_URL is unset" {
  unset ACTIONS_ID_TOKEN_REQUEST_URL
  echo '{"webhook_urls": {"value": {}}, "webhook_openbao_paths": {"value": []}}' > "$OUTPUTS_FILE"
  run bash "$SCRIPT" "$OUTPUTS_FILE"
  [ "$status" -ne 0 ]
  [[ "$output" == *"ACTIONS_ID_TOKEN_REQUEST_URL"* ]]
}

@test "logs in via GitHub OIDC with the webhooks-write role before writing" {
  cat > "$OUTPUTS_FILE" <<'JSON'
{"webhook_urls": {"value": {"argocd": "https://discord.test/argocd-hook"}},
 "webhook_openbao_paths": {"value": [{"key": "argocd", "path": "service/admin-discord/k8s-argocd/discord-webhook-url"}]}}
JSON

  run bash "$SCRIPT" "$OUTPUTS_FILE"
  [ "$status" -eq 0 ]

  grep -q "audience=openbao" "$CAPTURE_DIR/curl.calls"
  grep -q "auth/jwt/login" "$CAPTURE_DIR/curl.calls"
  [ "$(jq -r '.role' "$CAPTURE_DIR/login.log")" = "admin-discord-webhooks-oidc" ]
  [ "$(jq -r '.jwt' "$CAPTURE_DIR/login.log")" = "fake-oidc-jwt" ]
}

@test "posts each webhook's URL to its own OpenBao path, extracted from one outputs.json" {
  cat > "$OUTPUTS_FILE" <<'JSON'
{"webhook_urls": {"value": {"uptime": "https://discord.test/uptime-hook", "downtime": "https://discord.test/downtime-hook"}},
 "webhook_openbao_paths": {"value": [
   {"key": "uptime", "path": "service/admin-discord/pi-health/uptime-webhook-url"},
   {"key": "downtime", "path": "service/admin-discord/pi-health/downtime-webhook-url"}
 ]}}
JSON

  run bash "$SCRIPT" "$OUTPUTS_FILE"
  [ "$status" -eq 0 ]

  grep -q "kv/data/homelab/service/admin-discord/pi-health/uptime-webhook-url" "$CAPTURE_DIR/curl.calls"
  grep -q "kv/data/homelab/service/admin-discord/pi-health/downtime-webhook-url" "$CAPTURE_DIR/curl.calls"
  grep -q '"https://discord.test/uptime-hook"' "$CAPTURE_DIR/post.log"
  grep -q '"https://discord.test/downtime-hook"' "$CAPTURE_DIR/post.log"
}

@test "writes one webhook's URL to multiple OpenBao paths when it has more than one" {
  cat > "$OUTPUTS_FILE" <<'JSON'
{"webhook_urls": {"value": {"downtime": "https://discord.test/downtime-hook"}},
 "webhook_openbao_paths": {"value": [
   {"key": "downtime", "path": "service/admin-discord/pi-health/downtime-webhook-url"},
   {"key": "downtime", "path": "service/admin-discord/k8s-alertmanager/downtime-webhook-url"}
 ]}}
JSON

  run bash "$SCRIPT" "$OUTPUTS_FILE"
  [ "$status" -eq 0 ]

  grep -q "kv/data/homelab/service/admin-discord/pi-health/downtime-webhook-url" "$CAPTURE_DIR/curl.calls"
  grep -q "kv/data/homelab/service/admin-discord/k8s-alertmanager/downtime-webhook-url" "$CAPTURE_DIR/curl.calls"
  [ "$(wc -l < "$CAPTURE_DIR/post.log")" -eq 2 ]
  while IFS= read -r posted; do
    [ "$(echo "$posted" | jq -r '.data.value')" = "https://discord.test/downtime-hook" ]
  done < "$CAPTURE_DIR/post.log"
}

@test "sends the URL value wrapped in the data.value body" {
  cat > "$OUTPUTS_FILE" <<'JSON'
{"webhook_urls": {"value": {"argocd": "https://discord.test/argocd-hook"}},
 "webhook_openbao_paths": {"value": [{"key": "argocd", "path": "service/admin-discord/k8s-argocd/discord-webhook-url"}]}}
JSON

  run bash "$SCRIPT" "$OUTPUTS_FILE"
  [ "$status" -eq 0 ]

  posted=$(cat "$CAPTURE_DIR/post.log")
  [ "$(echo "$posted" | jq -r '.data.value')" = "https://discord.test/argocd-hook" ]
}

@test "writes nothing when webhook_openbao_paths is empty" {
  echo '{"webhook_urls": {"value": {}}, "webhook_openbao_paths": {"value": []}}' > "$OUTPUTS_FILE"

  run bash "$SCRIPT" "$OUTPUTS_FILE"
  [ "$status" -eq 0 ]
  [ ! -f "$CAPTURE_DIR/post.log" ]
}
