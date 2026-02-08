output "dns_records" {
  description = "Created DNS records"
  value = {
    portainer = cloudflare_record.portainer.hostname
    npm       = cloudflare_record.npm.hostname
    wildcard  = cloudflare_record.wildcard.hostname
  }
}

output "vm_ip" {
  description = "VM IP address"
  value       = var.vm_ip
}

output "cloudflare_zone_id" {
  description = "Cloudflare Zone ID"
  value       = data.cloudflare_zone.primary.id
}
