resource "discord_text_channel" "channels" {
  for_each = local.channels

  name      = each.key
  server_id = local.guild_id
}
