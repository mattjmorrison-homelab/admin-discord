# The one server this homelab uses. Not sensitive -- a guild ID grants no
# access on its own, same category as a namespace name or repo name, so it
# lives here in plain committed config rather than OpenBao.
locals {
  guild_id = "1534069041143218238"

  # Every channel this homelab actually uses. One discord_text_channel
  # resource per entry (see channels.tf).
  channels = {
    alerts        = {}
    deploys       = {}
    uptime        = {}
    downtime      = {}
    ad-blocked    = {}
    ad-suspicious = {}
  }

  # Every webhook this homelab actually uses. One discord_webhook resource
  # per entry (see webhooks.tf), posting into the named channel above.
  # `consumer` is documentation only. Each entry gets its own genuinely
  # distinct webhook object -- no sharing one webhook's value across
  # multiple consumers, even when they post into the same channel.
  webhooks = {
    alertmanager = {
      channel       = "alerts"
      consumer      = "k8s-alertmanager (general alerts)"
      openbao_paths = ["service/admin-discord/k8s-alertmanager/discord-webhook-url"]
    }
    argocd = {
      channel       = "deploys"
      consumer      = "k8s-argocd (sync/health notifications)"
      openbao_paths = ["service/admin-discord/k8s-argocd/discord-webhook-url"]
    }
    ui-hdmi-switch = {
      channel       = "deploys"
      consumer      = "ui-hdmi-switch's own CI failure-notify step"
      openbao_paths = ["service/admin-discord/ui-hdmi-switch/webhook-url"]
    }
    graph-hdmi-switch = {
      channel       = "deploys"
      consumer      = "graph-hdmi-switch's own CI failure-notify step"
      openbao_paths = ["service/admin-discord/graph-hdmi-switch/webhook-url"]
    }
    app-backstage = {
      channel       = "deploys"
      consumer      = "app-backstage's own CI failure-notify step"
      openbao_paths = ["service/admin-discord/app-backstage/webhook-url"]
    }
    uptime = {
      channel       = "uptime"
      consumer      = "pi-health (UPTIME_WEBHOOK_URL)"
      openbao_paths = ["service/admin-discord/pi-health/uptime-webhook-url"]
    }
    pi-health-downtime = {
      channel       = "downtime"
      consumer      = "pi-health (DOWNTIME_WEBHOOK_URL)"
      openbao_paths = ["service/admin-discord/pi-health/downtime-webhook-url"]
    }
    k8s-alertmanager-downtime = {
      channel       = "downtime"
      consumer      = "k8s-alertmanager (PiNodeExporterDown downtime proxy)"
      openbao_paths = ["service/admin-discord/k8s-alertmanager/downtime-webhook-url"]
    }
    k8s-healthchecks-downtime = {
      channel       = "downtime"
      consumer      = "k8s-healthchecks (dead-man's-switch notification)"
      openbao_paths = ["service/admin-discord/k8s-healthchecks/downtime-webhook-url"]
    }
    ad-reporter-confirmed = {
      channel       = "ad-blocked"
      consumer      = "ad-reporter-investigate skill (confirmed-ad domains it blocked)"
      openbao_paths = ["service/admin-discord/k8s-ad-reporter/confirmed-webhook-url"]
    }
    ad-reporter-suspicious = {
      channel       = "ad-suspicious"
      consumer      = "ad-reporter-investigate skill (ambiguous candidates, informational only)"
      openbao_paths = ["service/admin-discord/k8s-ad-reporter/suspicious-webhook-url"]
    }
  }
}
