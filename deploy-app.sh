#!/bin/bash
# ============================================
# Script de déploiement de l'application HR Directory
# ============================================
# Usage: ./deploy-app.sh <VM_IP> [SSH_USERNAME]

set -e

# Configuration
VM_IP="${1:-}"
SSH_USER="${2:-david}"
APP_DIR="/opt/hr-directory"

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction de log
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérification des arguments
if [ -z "$VM_IP" ]; then
    log_error "Usage: $0 <VM_IP> [SSH_USERNAME]"
    log_error "Exemple: $0 34.140.123.45 david"
    exit 1
fi

log_info "Déploiement de l'application HR Directory"
log_info "VM IP: $VM_IP"
log_info "SSH User: $SSH_USER"

# Vérification de la connexion SSH
log_info "Vérification de la connexion SSH..."
if ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${SSH_USER}@${VM_IP}" "echo 'SSH OK'" > /dev/null 2>&1; then
    log_error "Impossible de se connecter à la VM via SSH"
    log_error "Vérifiez que:"
    log_error "  - La VM est démarrée"
    log_error "  - Votre IP est autorisée dans le firewall GCP"
    log_error "  - Votre clé SSH est correctement configurée"
    exit 1
fi
log_info "Connexion SSH OK"

# Création de l'archive temporaire
log_info "Préparation des fichiers..."
TMP_DIR=$(mktemp -d)
tar -czf "${TMP_DIR}/app.tar.gz" -C app .

# Transfert des fichiers
log_info "Transfert des fichiers vers la VM..."
scp -o StrictHostKeyChecking=no "${TMP_DIR}/app.tar.gz" "${SSH_USER}@${VM_IP}:/tmp/"

# Nettoyage local
rm -rf "$TMP_DIR"

# Déploiement sur la VM
log_info "Déploiement sur la VM..."
ssh -o StrictHostKeyChecking=no "${SSH_USER}@${VM_IP}" << EOF
    set -e
    
    echo "Extraction des fichiers..."
    sudo mkdir -p ${APP_DIR}
    sudo tar -xzf /tmp/app.tar.gz -C ${APP_DIR}
    sudo rm /tmp/app.tar.gz
    
    echo "Configuration des permissions..."
    sudo chown -R www-data:www-data ${APP_DIR}
    sudo chmod -R 755 ${APP_DIR}
    
    echo "Création de l'environnement virtuel Python..."
    cd ${APP_DIR}
    sudo python3 -m venv venv
    sudo venv/bin/pip install --upgrade pip
    sudo venv/bin/pip install -r requirements.txt
    
    echo "Initialisation de la base de données..."
    sudo venv/bin/python -c "from app import init_db; init_db()"
    
    echo "Démarrage du service..."
    sudo systemctl daemon-reload
    sudo systemctl enable hr-directory
    sudo systemctl restart hr-directory
    
    echo "Vérification du statut..."
    sleep 2
    sudo systemctl status hr-directory --no-pager
    
    echo "Vérification de l'application..."
    curl -s http://localhost:5000/health || echo "Health check failed"
EOF

log_info "Déploiement terminé !"
log_info ""
log_info "L'application devrait être accessible localement sur la VM:"
log_info "  curl http://localhost:5000/health"
log_info ""
log_info "Prochaines étapes:"
log_info "  1. Configurez le tunnel Cloudflare sur la VM"
log_info "  2. Créez l'application Access dans Cloudflare One"
log_info "  3. Testez l'accès via https://hr.dgcf.ovh"
