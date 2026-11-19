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

# Not sensitive -- just KV paths. Flattened to one {key, path} object per
# path rather than per webhook, since a single webhook key (e.g. downtime)
# can list more than one path.
output "webhook_openbao_paths" {
  value = flatten([
    for k, v in local.webhooks : [
      for p in v.openbao_paths : { key = k, path = p }
    ]
  ])
}
