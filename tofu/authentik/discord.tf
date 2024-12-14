variable "discord_client_id" {
  type        = string
  description = "value of the client_id from the discord oauth app"
}

variable "discord_client_secret" {
  type        = string
  description = "value of the client_secret from the discord oauth app"
}

# Source

resource "authentik_source_oauth" "roxnet" {
  name                = "RoxNet Discord"
  slug                = "rox-net_discord"
  authentication_flow = authentik_flow.discord_authentication.uuid
  enrollment_flow     = authentik_flow.discord_enrollment.uuid
  user_matching_mode  = "email_deny"

  additional_scopes = "guilds guilds.members.read"

  provider_type   = "discord"
  consumer_key    = var.discord_client_id
  consumer_secret = var.discord_client_secret
}

resource "authentik_stage_identification" "discord" { # Identification stage, used to bind the discord source to main flow
  name              = "discord-ident"
  show_matched_user = true
  user_fields       = []
  sources           = [authentik_source_oauth.roxnet.uuid]
}

# Flow

## Discord flow

resource "authentik_flow" "discord_authentication" { # Authentication flow
  name        = "Røstvik"
  title       = "Røstvik"
  slug        = "discord"
  designation = "authentication"
}

resource "authentik_flow_stage_binding" "discord_login" { #  Bind the discord flow to the login stage
  target = authentik_flow.discord_authentication.uuid
  stage  = authentik_stage_user_login.this.id
  order  = 90
}

## Enrollment flow

resource "authentik_flow" "discord_enrollment" { # Enrollment
  name        = "roxnet-discord"
  title       = "roxnet-discord"
  slug        = "roxnet-discord-enrollment"
  designation = "enrollment"
}

resource "authentik_stage_user_write" "discord" { # Write stage, used to create users
  name                     = "discord-write"
  create_users_as_inactive = false
  create_users_group       = authentik_group.discord_users.id
  user_type                = "internal"
}

resource "authentik_flow_stage_binding" "enroll_discord" { # Bind the enrollment flow to the write stage
  target = authentik_flow.discord_enrollment.uuid
  stage  = authentik_stage_user_write.discord.id
  order  = 0
}

resource "authentik_flow_stage_binding" "login_discord" { # Bind the enrollment flow to the login stage
  target = authentik_flow.discord_enrollment.uuid
  stage  = authentik_stage_user_login.discord.id
  order  = 30
}

resource "authentik_stage_user_login" "discord" { # Login stage, used to authenticate users
  name = "discord-login"
}

# Groups

resource "authentik_group" "discord_users" { # This is the default group for all discord users
  name         = "discord-users"
  is_superuser = false

  lifecycle {
    ignore_changes = [users]
  }
}

resource "authentik_group" "discord_snok" { # This is the group for the datasnok discord role, synced on enrollment and login
  name         = "discord-datasnok"
  is_superuser = false
  attributes = jsonencode({
    "discord_role_id" = "456016476915367937"
  })

  lifecycle {
    ignore_changes = [users]
  }
}

# Policy Expressions

variable "discord_guild_id" {
  type        = string
  description = "allowlist of guild to allow access to"
}

##  Check if the user is in the correct guild on enrollment

resource "authentik_policy_expression" "match_guild" {
  name       = "matchGuild"
  expression = templatefile("${path.module}/expressionPolicies/discordMatchGuild.py.tftpl", { guild = var.discord_guild_id, guildName = "serverrrrr" })
}

resource "authentik_policy_binding" "match_guild_enroll" {
  target = authentik_flow.discord_enrollment.uuid
  policy = authentik_policy_expression.match_guild.id
  order  = 0
}

## Sync the user's roles

### On login

resource "authentik_policy_expression" "sync_auth_role" {
  name       = "syncAuthRoles"
  expression = templatefile("${path.module}/expressionPolicies/discordSyncRoleAuth.py.tfpl", { guild = var.discord_guild_id })
}

resource "authentik_policy_binding" "sync_auth_role" {
  target = authentik_flow.discord_authentication.uuid
  policy = authentik_policy_expression.sync_auth_role.id
  order  = 0
}

### On enrollment

resource "authentik_policy_expression" "sync_enroll_role" {
  name       = "syncEnrollRoles"
  expression = templatefile("${path.module}/expressionPolicies/discordSyncRoleEnroll.py.tfpl", { guild = var.discord_guild_id })
}

resource "authentik_policy_binding" "sync_enroll_role" {
  target = authentik_flow_stage_binding.login_discord.id
  policy = authentik_policy_expression.sync_enroll_role.id
  order  = 0
}

## Sync the user's avatar attribute

resource "authentik_policy_expression" "sync_avatar" {
  name       = "syncAvatar"
  expression = templatefile("${path.module}/expressionPolicies/discordAvatarGrab.py.tftpl", {})
}

resource "authentik_policy_binding" "sync_enroll_avatar" {
  target = authentik_flow_stage_binding.login_discord.id
  policy = authentik_policy_expression.sync_avatar.id
  order  = 0
}

resource "authentik_policy_binding" "sync_auth_avatar" {
  target = authentik_flow.discord_authentication.uuid
  policy = authentik_policy_expression.sync_avatar.id
  order  = 0
}
