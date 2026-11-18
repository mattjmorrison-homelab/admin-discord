# Real webhook URLs -- Sensitive is already set by the provider's own
# schema (redacts CLI/plan output), but these outputs still land in this
# repo's Terraform state as plaintext, same as any resource anywhere. See
# README.md for why that's an accepted, scoped exception here.
#
# View a specific one with: tofu output -raw <key>
output "webhook_urls" {
  value     = { for k, w in discord_webhook.webhooks : k => w.url }
  sensitive = true
}

# Drives tofu.yml's generic write-back loop and its pre-merge OpenBao
# grant check -- not sensitive, just KV paths.
output "webhook_openbao_paths" {
  value = { for k, v in local.webhooks : k => v.openbao_path }
}
