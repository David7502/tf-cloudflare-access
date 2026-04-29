# ============================================
# Outputs - Cloudflare Access HR Directory
# ============================================

locals {
  # Vérification si le tunnel est configuré (évite de référencer la variable sensible directement dans les outputs)
  has_tunnel_token = length(var.cloudflare_tunnel_token) > 0

  next_steps_auto = <<-EOT

    ============================================
    DÉPLOIEMENT TERRAFORM TERMINÉ ✨
    ============================================

    🚀 TUNNEL AUTO-CONFIGURÉ !
    
    1. Attendez que l'installation se termine (5-10 min)
       Vérifiez: ssh ${var.ssh_username}@${google_compute_instance.access_hr_vm.network_interface[0].access_config[0].nat_ip} "sudo tail /var/log/startup-script.log"

    2. Déployez l'application:
       ./deploy-app.sh ${google_compute_instance.access_hr_vm.network_interface[0].access_config[0].nat_ip}

    3. Ajoutez une Public Hostname dans Cloudflare One:
       - Subdomain: hr
       - Domain: dgcf.ovh
       - Type: HTTP
       - URL: localhost:80

    4. Créez une application Access:
       https://one.dash.cloudflare.com → Access → Applications
       - Domain: hr.dgcf.ovh
       - IdP: Authentik

    5. Testez: https://hr.dgcf.ovh

    ============================================
  EOT

  next_steps_manual = <<-EOT

    ============================================
    DÉPLOIEMENT TERRAFORM TERMINÉ
    ============================================

    1. Attendez que l'installation se termine (5-10 min)
       Vérifiez: ssh ${var.ssh_username}@${google_compute_instance.access_hr_vm.network_interface[0].access_config[0].nat_ip} "sudo tail /var/log/startup-script.log"

    2. Déployez l'application:
       ./deploy-app.sh ${google_compute_instance.access_hr_vm.network_interface[0].access_config[0].nat_ip}

    3. Créez un tunnel dans Cloudflare One:
       https://one.dash.cloudflare.com → Networks → Tunnels
       Nom: hr-directory-tunnel

    4. Installez le token sur la VM:
       ssh ${var.ssh_username}@${google_compute_instance.access_hr_vm.network_interface[0].access_config[0].nat_ip}
       sudo cloudflared service install <TOKEN>

    5. Ajoutez une Public Hostname et créez une application Access

    6. Testez: https://hr.dgcf.ovh

    💡 ASTUCE: Pour éviter l'étape 4, ajoutez cloudflare_tunnel_token dans terraform.tfvars

    ============================================
  EOT
}

output "access_instance_ip" {
  description = "IP publique de la VM HR Directory"
  value       = google_compute_instance.access_hr_vm.network_interface[0].access_config[0].nat_ip
}

output "access_instance_name" {
  description = "Nom de l'instance VM"
  value       = google_compute_instance.access_hr_vm.name
}

output "ssh_command" {
  description = "Commande SSH pour se connecter"
  value       = "ssh ${var.ssh_username}@${google_compute_instance.access_hr_vm.network_interface[0].access_config[0].nat_ip}"
}

output "tunnel_configured" {
  description = "Indique si le tunnel Cloudflare est auto-configuré"
  value       = local.has_tunnel_token ? "OUI - Tunnel auto-configuré" : "NON - Configuration manuelle requise"
  sensitive   = true
}

output "next_steps" {
  description = "Instructions post-déploiement"
  value       = local.has_tunnel_token ? local.next_steps_auto : local.next_steps_manual
  sensitive   = true
}
