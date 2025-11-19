resource "grafana_folder" "amx" {
  title = "AMXtest"
}
resource "grafana_dashboard" "imported_dashboard" {
  config_json = file("${path.module}/dashboards/Nginx-1761452198849.json")
  folder      = grafana_folder.amx.id  # <-- Use ID instead of string
  message     = "Imported via Terraform"
 # overwrite = true
}
