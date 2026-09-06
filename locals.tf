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
  # `consumer` is documentation only (which repo/service reads this
  # webhook's URL) -- getting the real URL into that consumer's own
  # OpenBao path is still a manual copy step, same as before this repo
  # existed; this doesn't automate that part.
  webhooks = {
    alertmanager = {
      channel  = "alerts"
      consumer = "k8s-alertmanager (general alerts)"
    }
    argocd = {
      channel  = "deploys"
      consumer = "k8s-argocd (sync/health notifications)"
    }
    github-actions = {
      channel  = "deploys"
      consumer = "shared across every repo's CI failure-notify step (ui-hdmi-switch, graph-hdmi-switch, graph-router, ...)"
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
