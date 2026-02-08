terraform {
  required_version = ">= 1.0"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Zone is already created in Cloudflare - using data source to reference it
# If you need to create a new zone, change this to cloudflare_zone resource
data "cloudflare_zone" "primary" {
  name       = var.domain
  account_id = var.cloudflare_account_id
}

# A record for portainer subdomain
resource "cloudflare_record" "portainer" {
  zone_id = data.cloudflare_zone.primary.id
  name    = "portainer"
  content = var.vm_ip
  type    = "A"
  ttl     = 1
  proxied = true
}

# A record for portainer subdomain
resource "cloudflare_record" "worker" {
  zone_id = data.cloudflare_zone.primary.id
  name    = "worker"
  content = var.vm_ip
  type    = "A"
  ttl     = 1
  proxied = true
}

# A record for npm subdomain (optional, for direct access)
resource "cloudflare_record" "npm" {
  zone_id = data.cloudflare_zone.primary.id
  name    = "npm"
  content = var.vm_ip
  type    = "A"
  ttl     = 1
  proxied = true
}

# Wildcard record for future services
resource "cloudflare_record" "wildcard" {
  zone_id = data.cloudflare_zone.primary.id
  name    = "*.apps"
  content = var.vm_ip
  type    = "A"
  ttl     = 1
  proxied = true
}
