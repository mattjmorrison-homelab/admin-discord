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
