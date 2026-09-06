resource "discord_webhook" "webhooks" {
  for_each = local.webhooks

  channel_id = discord_text_channel.channels[each.value.channel].channel_id
  name       = each.key
}
