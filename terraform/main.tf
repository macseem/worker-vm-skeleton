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

# Get the zone data
resource "cloudflare_zone" "primary" {
  zone = var.domain
}

# A record for portainer subdomain
resource "cloudflare_record" "portainer" {
  zone_id = cloudflare_zone.primary.id
  name    = "portainer"
  content = var.vm_ip
  type    = "A"
  ttl     = 300
  proxied = true
}

# A record for portainer subdomain
resource "cloudflare_record" "worker" {
  zone_id = cloudflare_zone.primary.id
  name    = "worker"
  content = var.vm_ip
  type    = "A"
  ttl     = 300
  proxied = true
}

# A record for npm subdomain (optional, for direct access)
resource "cloudflare_record" "npm" {
  zone_id = cloudflare_zone.primary.id
  name    = "npm"
  content = var.vm_ip
  type    = "A"
  ttl     = 300
  proxied = true
}

# Wildcard record for future services
resource "cloudflare_record" "wildcard" {
  zone_id = cloudflare_zone.primary.id
  name    = "*.apps"
  content = var.vm_ip
  type    = "A"
  ttl     = 300
  proxied = true
}
