# ============================================
# Outputs - Cloudflare Access HR Directory
# ============================================

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

output "next_steps" {
  description = "Instructions post-déploiement"
  value       = <<-EOT

    ============================================
    DÉPLOIEMENT TERRAFORM TERMINÉ
    ============================================

    1. Attendez que l'installation automatique se termine (5-10 min)
       Vérifiez avec : ssh ${var.ssh_username}@${google_compute_instance.access_hr_vm.network_interface[0].access_config[0].nat_ip} "sudo tail -f /var/log/syslog | grep startup-script"

    2. Déployez les fichiers de l'application :
       ./deploy-app.sh ${google_compute_instance.access_hr_vm.network_interface[0].access_config[0].nat_ip}

    3. Configurez Cloudflare Access :

       a. Créez un tunnel dans Cloudflare One :
          https://one.dash.cloudflare.com → Networks → Tunnels → Create a tunnel
          Nom : hr-directory-tunnel

       b. Copiez le token, puis sur la VM :
          ssh ${var.ssh_username}@${google_compute_instance.access_hr_vm.network_interface[0].access_config[0].nat_ip}
          sudo cloudflared service install <TOKEN>

       c. Ajoutez une Public Hostname :
          - Subdomain: hr
          - Domain: dgcf.ovh
          - Type: HTTP
          - URL: localhost:80

       d. Créez une application Access :
          https://one.dash.cloudflare.com → Access → Applications → Add an application
          - Type: Self-hosted
          - Name: HR Directory
          - Domain: hr.dgcf.ovh
          - IdP: Authentik (sélectionnez-le)
          - Policy: Create Allow policy → Include → Email → votre email

    4. Testez l'accès : https://hr.dgcf.ovh

    ============================================
  EOT
}
