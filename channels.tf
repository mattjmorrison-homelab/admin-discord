resource "discord_text_channel" "channels" {
  for_each = local.channels

  name      = each.key
  server_id = local.guild_id

  # The provider defaults this to true and errors ("Can't sync
  # permissions with category") on any channel with no category set --
  # confirmed against a real apply. None of these channels use
  # categories, so there's nothing to sync with.
  sync_perms_with_category = false
}
