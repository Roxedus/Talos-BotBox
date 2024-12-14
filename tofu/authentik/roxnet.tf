resource "authentik_brand" "roxnet" {
  domain              = "roxedus.net"
  default             = true
  branding_title      = "Roxedus.net Identity"
  branding_logo       = "/static/dist/assets/icons/icon_left_brand.svg"
  branding_favicon    = "/static/dist/assets/icons/icon.png"
  flow_authentication = authentik_flow.login_authentication.uuid
}
