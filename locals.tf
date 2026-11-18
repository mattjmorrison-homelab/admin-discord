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
  # `openbao_path` drives tofu.yml's apply job, which loops over every
  # entry here (via outputs.tf's webhook_urls + webhook_openbao_paths
  # outputs) and pushes each one's real URL into that path itself, right
  # after creating it -- adding a webhook here is enough, no new CI step
  # required. Consumers only ever read OpenBao, never this repo's
  # Terraform state directly. The check job's pre-merge validate step
  # asserts OpenBao already has a create/update grant for every path here.
  webhooks = {
    # alertmanager/argocd: no write-back step in tofu.yml's apply job --
    # pre-existing, deliberately untouched here. Their openbao_path values
    # are their real, already-live flat paths (see admin-openbao's
    # locals.tf secret-scaffold map + the k8s-argocd role's own policy),
    # not the service/admin-discord/... convention the other 7 use --
    # adding them here is a no-op for the new generic write loop, it just
    # lets that loop cover every webhook uniformly without special-casing
    # these two.
    alertmanager = {
      channel      = "alerts"
      consumer     = "k8s-alertmanager (general alerts)"
      openbao_path = "k8s-alertmanager/discord-webhook-url"
    }
    argocd = {
      channel      = "deploys"
      consumer     = "k8s-argocd (sync/health notifications)"
      openbao_path = "k8s-argocd/discord-webhook-url"
    }
    # Replaces the old single shared "github-actions" webhook --
    # ui-hdmi-switch and graph-hdmi-switch each get their own dedicated
    # object now (same "deploys" channel, genuinely distinct webhooks).
    # graph-router was named as an intended third consumer in the old
    # shared webhook's doc string, but was confirmed (org-wide grep)
    # to have no Discord notify step wired up at all -- not migrated,
    # nothing to migrate.
    ui-hdmi-switch = {
      channel      = "deploys"
      consumer     = "ui-hdmi-switch's own CI failure-notify step"
      openbao_path = "service/admin-discord/ui-hdmi-switch/webhook-url"
    }
    graph-hdmi-switch = {
      channel      = "deploys"
      consumer     = "graph-hdmi-switch's own CI failure-notify step"
      openbao_path = "service/admin-discord/graph-hdmi-switch/webhook-url"
    }
    app-backstage = {
      channel = "deploys"
      # Its webhook object was created successfully on the first apply
      # (#13), but writing the value into OpenBao failed -- that apply
      # landed 12s before admin-openbao#86 (the grant letting this repo's
      # own CI write app-backstage's specific webhook-url path) actually
      # applied, so the token minted for that run predated the
      # permission it needed. Re-running the same job then failed with
      # "Saved plan is stale" (state had already moved since that plan
      # was made). This otherwise-no-op change exists purely to force a
      # fresh plan+apply now that the grant has been live for a while.
      consumer     = "app-backstage's own CI failure-notify step"
      openbao_path = "service/admin-discord/app-backstage/webhook-url"
    }
    uptime = {
      channel      = "uptime"
      consumer     = "pi-health (UPTIME_WEBHOOK_URL)"
      openbao_path = "service/admin-discord/pi-health/uptime-webhook-url"
    }
    downtime = {
      channel      = "downtime"
      consumer     = "pi-health (DOWNTIME_WEBHOOK_URL) and k8s-alertmanager (PiNodeExporterDown downtime proxy)"
      openbao_path = "service/admin-discord/pi-health/downtime-webhook-url"
    }
    ad-reporter-confirmed = {
      channel      = "ad-blocked"
      consumer     = "ad-reporter-investigate skill (confirmed-ad domains it blocked)"
      openbao_path = "service/admin-discord/k8s-ad-reporter/confirmed-webhook-url"
    }
    ad-reporter-suspicious = {
      channel      = "ad-suspicious"
      consumer     = "ad-reporter-investigate skill (ambiguous candidates, informational only)"
      openbao_path = "service/admin-discord/k8s-ad-reporter/suspicious-webhook-url"
    }
  }
}
