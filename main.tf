# ============================================
# Cloudflare Access HR Directory - Infrastructure GCP
# ============================================
# Ce fichier crée une VM pour héberger une application Flask
# sécurisée par Cloudflare Access avec Authentik comme IdP

# VPC avec préfixe access-
resource "google_compute_network" "access_vpc" {
  name                    = var.access_vpc_name
  auto_create_subnetworks = false
}

# Sous-réseau avec CIDR unique
resource "google_compute_subnetwork" "access_subnet" {
  name          = var.access_subnet_name
  ip_cidr_range = var.access_subnet_cidr
  network       = google_compute_network.access_vpc.id
  region        = var.region
}

# Firewall SSH - accès limité à l'IP de l'utilisateur
resource "google_compute_firewall" "access_allow_ssh" {
  name        = var.access_firewall_name
  network     = google_compute_network.access_vpc.name
  target_tags = ["access-ssh-enabled"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = [var.my_ip]
}

# VM e2-micro (free tier eligible)
resource "google_compute_instance" "access_hr_vm" {
  name         = var.access_instance_name
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["access-ssh-enabled"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
    }
  }

  network_interface {
    network    = google_compute_network.access_vpc.name
    subnetwork = google_compute_subnetwork.access_subnet.name
    access_config {} # IP publique éphémère
  }

  metadata = {
    ssh-keys = "${var.ssh_username}:${var.ssh_public_key}"
  }

  metadata_startup_script = file("${path.module}/startup.sh")
}
