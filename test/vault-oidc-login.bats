#!/usr/bin/env bats

setup() {
  export PATH="$BATS_TEST_DIRNAME/mocks:$PATH"
  export CAPTURE_DIR="$BATS_TEST_TMPDIR"
  LIB="$BATS_TEST_DIRNAME/../scripts/lib/vault-oidc-login.sh"
  export VAULT_ADDR="http://vault.test"
  export ACTIONS_ID_TOKEN_REQUEST_TOKEN="fake-request-token"
  export ACTIONS_ID_TOKEN_REQUEST_URL="https://actions.test/oidc?foo=bar"
}

@test "fails when no role is given" {
  run bash -c "source '$LIB' && vault_oidc_login"
  [ "$status" -ne 0 ]
  [[ "$output" == *"usage:"* ]]
}

@test "fails when VAULT_ADDR is unset" {
  unset VAULT_ADDR
  run bash -c "source '$LIB' && vault_oidc_login some-role"
  [ "$status" -ne 0 ]
  [[ "$output" == *"VAULT_ADDR"* ]]
}

@test "fails when ACTIONS_ID_TOKEN_REQUEST_TOKEN is unset" {
  unset ACTIONS_ID_TOKEN_REQUEST_TOKEN
  run bash -c "source '$LIB' && vault_oidc_login some-role"
  [ "$status" -ne 0 ]
  [[ "$output" == *"ACTIONS_ID_TOKEN_REQUEST_TOKEN"* ]]
}

@test "fails when ACTIONS_ID_TOKEN_REQUEST_URL is unset" {
  unset ACTIONS_ID_TOKEN_REQUEST_URL
  run bash -c "source '$LIB' && vault_oidc_login some-role"
  [ "$status" -ne 0 ]
  [[ "$output" == *"ACTIONS_ID_TOKEN_REQUEST_URL"* ]]
}

@test "exchanges the GitHub OIDC token for a Vault client token via the given role" {
  run bash -c "source '$LIB' && vault_oidc_login admin-discord-webhooks-oidc"
  [ "$status" -eq 0 ]
  [[ "$output" == *"fake-webhooks-token"* ]]

  grep -q "audience=openbao" "$CAPTURE_DIR/curl.calls"
  grep -q "auth/jwt/login" "$CAPTURE_DIR/curl.calls"
  [ "$(jq -r '.role' "$CAPTURE_DIR/login.log")" = "admin-discord-webhooks-oidc" ]
  [ "$(jq -r '.jwt' "$CAPTURE_DIR/login.log")" = "fake-oidc-jwt" ]
}

@test "requests the OIDC token with the audience=openbao query param and bearer auth header" {
  run bash -c "source '$LIB' && vault_oidc_login some-role"
  [ "$status" -eq 0 ]

  grep -q "Authorization: bearer fake-request-token" "$CAPTURE_DIR/curl.calls"
  grep -q "https://actions.test/oidc?foo=bar&audience=openbao" "$CAPTURE_DIR/curl.calls"
}

@test "masks the client token in the Actions log" {
  run bash -c "source '$LIB' && vault_oidc_login some-role"
  [ "$status" -eq 0 ]
  [[ "$output" == *"::add-mask::fake-webhooks-token"* ]]
}

@test "uses a different role when a different Vault role name is passed" {
  run bash -c "source '$LIB' && vault_oidc_login another-role"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.role' "$CAPTURE_DIR/login.log")" = "another-role" ]
}
