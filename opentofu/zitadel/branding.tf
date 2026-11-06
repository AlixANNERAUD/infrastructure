# Zitadel's own colors, without its watermark or the login name's domain suffix
resource "zitadel_label_policy" "organization" {
  org_id = zitadel_org.organization.id

  primary_color    = "#5469d4"
  background_color = "#fafafa"
  warn_color       = "#cd3d56"
  font_color       = "#000000"

  primary_color_dark    = "#a5b4fc"
  background_color_dark = "#111827"
  warn_color_dark       = "#ff3b5b"
  font_color_dark       = "#ffffff"

  disable_watermark      = true
  hide_login_name_suffix = true
  set_active             = true
}
