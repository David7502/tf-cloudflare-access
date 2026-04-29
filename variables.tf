# ============================================
# Variables - Cloudflare Access HR Directory Lab
# ============================================

# GCP Project Configuration
variable "project_id" {
  description = "ID du projet GCP"
  type        = string
}

variable "region" {
  description = "Région GCP"
  type        = string
  default     = "europe-west1"
}

variable "zone" {
  description = "Zone GCP"
  type        = string
  default     = "europe-west1-b"
}

# Resource Naming - Prefix: access-
variable "access_instance_name" {
  description = "Nom de l'instance VM"
  type        = string
  default     = "vm-access-hr-directory"
}

variable "access_vpc_name" {
  description = "Nom du VPC"
  type        = string
  default     = "access-vpc"
}

variable "access_subnet_name" {
  description = "Nom du sous-réseau"
  type        = string
  default     = "access-subnet"
}

variable "access_firewall_name" {
  description = "Nom de la règle firewall"
  type        = string
  default     = "access-allow-ssh"
}

variable "access_subnet_cidr" {
  description = "CIDR du sous-réseau (différent du repo appsec)"
  type        = string
  default     = "10.1.0.0/24"
}

# SSH Configuration
variable "ssh_username" {
  description = "Nom d'utilisateur SSH"
  type        = string
  default     = "david"
}

variable "ssh_public_key" {
  description = "Clé SSH publique pour l'accès à la VM"
  type        = string
}

variable "my_ip" {
  description = "Votre adresse IP publique pour restreindre l'accès SSH (défaut: 0.0.0.0/0 = toutes les IP)"
  type        = string
  default     = "0.0.0.0/0"
}

# Cloudflare Tunnel Configuration (optional)
variable "cloudflare_tunnel_token" {
  description = "Token du tunnel Cloudflare (optionnel - permet l'autoconfiguration du tunnel)"
  type        = string
  default     = ""
  sensitive   = true
}
