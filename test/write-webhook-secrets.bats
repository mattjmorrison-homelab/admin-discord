#!/usr/bin/env bats

setup() {
  export PATH="$BATS_TEST_DIRNAME/mocks:$PATH"
  export CAPTURE_DIR="$BATS_TEST_TMPDIR"
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/write-webhook-secrets.sh"
  export VAULT_ADDR="http://vault.test"
  export WEBHOOKS_TOKEN="fake-webhooks-token"

  URLS_FILE="$BATS_TEST_TMPDIR/webhook_urls.json"
  PATHS_FILE="$BATS_TEST_TMPDIR/webhook_openbao_paths.json"
}

@test "fails when the webhook_urls.json argument is missing" {
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage:"* ]]
}

@test "fails when VAULT_ADDR is unset" {
  unset VAULT_ADDR
  echo '{}' > "$URLS_FILE"
  echo '{}' > "$PATHS_FILE"
  run bash "$SCRIPT" "$URLS_FILE" "$PATHS_FILE"
  [ "$status" -ne 0 ]
  [[ "$output" == *"VAULT_ADDR"* ]]
}

@test "fails when WEBHOOKS_TOKEN is unset" {
  unset WEBHOOKS_TOKEN
  echo '{}' > "$URLS_FILE"
  echo '{}' > "$PATHS_FILE"
  run bash "$SCRIPT" "$URLS_FILE" "$PATHS_FILE"
  [ "$status" -ne 0 ]
  [[ "$output" == *"WEBHOOKS_TOKEN"* ]]
}

@test "posts each webhook's URL to its own OpenBao path" {
  cat > "$URLS_FILE" <<'JSON'
{"uptime": "https://discord.test/uptime-hook", "downtime": "https://discord.test/downtime-hook"}
JSON
  cat > "$PATHS_FILE" <<'JSON'
{"uptime": "service/admin-discord/pi-health/uptime-webhook-url", "downtime": "service/admin-discord/pi-health/downtime-webhook-url"}
JSON

  run bash "$SCRIPT" "$URLS_FILE" "$PATHS_FILE"
  [ "$status" -eq 0 ]

  grep -q "kv/data/homelab/service/admin-discord/pi-health/uptime-webhook-url" "$CAPTURE_DIR/curl.calls"
  grep -q "kv/data/homelab/service/admin-discord/pi-health/downtime-webhook-url" "$CAPTURE_DIR/curl.calls"
  grep -q '"https://discord.test/uptime-hook"' "$CAPTURE_DIR/post.log"
  grep -q '"https://discord.test/downtime-hook"' "$CAPTURE_DIR/post.log"
}

@test "sends the URL value wrapped in the data.value body" {
  cat > "$URLS_FILE" <<'JSON'
{"argocd": "https://discord.test/argocd-hook"}
JSON
  cat > "$PATHS_FILE" <<'JSON'
{"argocd": "k8s-argocd/discord-webhook-url"}
JSON

  run bash "$SCRIPT" "$URLS_FILE" "$PATHS_FILE"
  [ "$status" -eq 0 ]

  posted=$(cat "$CAPTURE_DIR/post.log")
  [ "$(echo "$posted" | jq -r '.data.value')" = "https://discord.test/argocd-hook" ]
}

@test "writes nothing when webhook_openbao_paths.json is empty" {
  echo '{}' > "$URLS_FILE"
  echo '{}' > "$PATHS_FILE"

  run bash "$SCRIPT" "$URLS_FILE" "$PATHS_FILE"
  [ "$status" -eq 0 ]
  [ ! -f "$CAPTURE_DIR/post.log" ]
}
