terraform {
  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "~> 2.0"
    }
  }
}

provider "grafana" {
  url  = "https://grafanaops.airlinq.com:3000"
  auth = var.grafana_api_token   # your API token
  insecure_skip_verify = true    # <--- THIS is correct for self-signed HTTPS
}
