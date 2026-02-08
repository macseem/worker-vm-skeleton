variable "cloudflare_api_token" {
  description = "Cloudflare API Token with DNS edit permissions"
  type        = string
  sensitive   = true
}

variable "domain" {
  description = "Primary domain (e.g., dudkin-garage.com)"
  type        = string
  default     = "dudkin-garage.com"
}

variable "vm_ip" {
  description = "Public IP address of the VM"
  type        = string
}

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID"
  type        = string
}

variable "enable_portainer" {
  description = "Create DNS record for portainer subdomain"
  type        = bool
  default     = true
}

variable "enable_npm" {
  description = "Create DNS record for npm subdomain"
  type        = bool
  default     = true
}

variable "enable_wildcard" {
  description = "Create wildcard DNS record"
  type        = bool
  default     = true
}
