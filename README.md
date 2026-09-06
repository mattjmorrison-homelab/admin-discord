# admin-discord

Manages this homelab's Discord channels and webhooks via Terraform,
using [`Lucky3028/terraform-provider-discord`](https://github.com/Lucky3028/terraform-provider-discord)
(most active of the community Discord providers surveyed — no official,
HashiCorp/Discord-maintained one exists).

Before this repo existed, every webhook was created by hand in Discord's
UI, with no record anywhere of which channel it posted to or why — that
kept causing "is this the deploys channel?" guessing whenever a new one
got wired up. See `.github`'s `docs/TODO.md` for the fuller history.

## A real, accepted exception to "no secrets in state"

Every webhook's token/URL is a plain computed (`Sensitive`-flagged, not
write-only) attribute in this provider — checked directly against its
schema, and confirmed the same in every alternative provider surveyed.
`Sensitive` only redacts CLI/plan display; the real value still lands in
this repo's own Terraform state and in `tofu plan`'s output artifact,
same as any resource anywhere.

This is only acceptable because plans are stored in Garage now, not a
public GitHub Actions artifact (see `actions-tofu`'s `upload-plan`/
`download-plan`) — without that, a real webhook token would leak onto a
public PR the first time any later PR touched this repo. State itself
was already Garage-backed like every other repo here, gated by the same
shared credential (not per-secret ACLed) — this repo doesn't change that
risk profile, it just makes the plan-artifact side of it consistent with
everything else.

## What's not automated

Creating a webhook here doesn't write its URL into the consuming repo's
own OpenBao path (e.g. `ui-hdmi-switch`'s
`homelab/ui-hdmi-switch/discord-webhook-url`) — that's still a manual
copy step, same as before this repo existed. `locals.tf`'s `webhooks`
map documents which repo/service consumes each one, so that copy step at
least has a clear source of truth now.

## Adding a new channel or webhook

Add an entry to `locals.channels` or `locals.webhooks` in `locals.tf` —
`channels.tf`/`webhooks.tf` generate the actual resources from those maps,
nothing else needs editing.

## Bot setup (one-time, manual)

1. Create a bot application in [Discord's Developer Portal](https://discord.com/developers/applications).
2. Grant it the `Manage Channels` and `Manage Webhooks` permissions and
   invite it to the server (guild ID in `locals.tf`).
3. Copy its token into OpenBao at `kv/data/homelab/admin-discord/discord-bot-token`
   (property `value`) — scaffolded blank by `admin-openbao`'s `secrets`
   map, filled in manually like every other real secret value in this
   homelab.
