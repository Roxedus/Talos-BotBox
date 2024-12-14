resource "authentik_flow" "login_authentication" {
  name        = "Roxedus.net"
  title       = "roxedus.net"
  slug        = "login"
  designation = "authentication"
}

resource "authentik_flow_stage_binding" "auth_discord_ident" {
  target = authentik_flow.login_authentication.uuid
  stage  = authentik_stage_identification.discord.id
  order  = 10
}

resource "authentik_stage_user_login" "this" {
  name = "user-login"
}

resource "authentik_system_settings" "settings" {
  avatars = "attributes.avatar,gravatar,initials"
}
