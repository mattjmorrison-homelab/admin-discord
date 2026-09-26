# The one server this homelab uses. Not sensitive -- a guild ID grants no
# access on its own, same category as a namespace name or repo name, so it
# lives here in plain committed config rather than OpenBao.
locals {
  guild_id = "1534069041143218238"

  # Every channel this homelab actually uses. One discord_text_channel
  # resource per entry (see channels.tf).
  channels = {
    alerts   = {}
    deploys  = {}
    uptime   = {}
    downtime = {}
  }

  # Every webhook this homelab actually uses. One discord_webhook resource
  # per entry (see webhooks.tf), posting into the named channel above.
  # `consumer` is documentation only. Each entry gets its own genuinely
  # distinct webhook object -- no sharing one webhook's value across
  # multiple consumers, even when they post into the same channel.
  # tofu.yml's apply job pushes each one's real URL into that
  # consumer's own OpenBao path itself, right after creating it (see
  # outputs.tf's webhook_urls output + the write-secret steps) --
  # consumers only ever read OpenBao, never this repo's Terraform
  # state directly.
  webhooks = {
    alertmanager = {
      channel  = "alerts"
      consumer = "k8s-alertmanager (general alerts)"
    }
    argocd = {
      channel  = "deploys"
      consumer = "k8s-argocd (sync/health notifications)"
    }
    # Replaces the old single shared "github-actions" webhook --
    # ui-hdmi-switch and graph-hdmi-switch each get their own dedicated
    # object now (same "deploys" channel, genuinely distinct webhooks).
    # graph-router was named as an intended third consumer in the old
    # shared webhook's doc string, but was confirmed (org-wide grep)
    # to have no Discord notify step wired up at all -- not migrated,
    # nothing to migrate.
    ui-hdmi-switch = {
      channel  = "deploys"
      consumer = "ui-hdmi-switch's own CI failure-notify step"
    }
    graph-hdmi-switch = {
      channel  = "deploys"
      consumer = "graph-hdmi-switch's own CI failure-notify step"
    }
    uptime = {
      channel  = "uptime"
      consumer = "pi-health (UPTIME_WEBHOOK_URL)"
    }
    downtime = {
      channel  = "downtime"
      consumer = "pi-health (DOWNTIME_WEBHOOK_URL) and k8s-alertmanager (PiNodeExporterDown downtime proxy)"
    }
  }
}
