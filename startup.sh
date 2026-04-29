#!/bin/bash
# ============================================
# Script d'installation automatique - HR Directory
# Exécuté au premier boot de la VM
# ============================================

set -e

LOG_FILE="/var/log/startup-script.log"
exec > >(tee -a $LOG_FILE)
exec 2>&1

echo "=== Démarrage installation HR Directory === $(date)"

# Mise à jour système
echo "Mise à jour du système..."
apt-get update
apt-get upgrade -y

# Installation des dépendances
echo "Installation des dépendances..."
apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    nginx \
    sqlite3 \
    curl \
    wget \
    git

# Installation de cloudflared
echo "Installation de cloudflared..."
if ! command -v cloudflared &> /dev/null; then
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    dpkg -i cloudflared-linux-amd64.deb
    rm cloudflared-linux-amd64.deb
    echo "cloudflared installé avec succès"
else
    echo "cloudflared déjà installé"
fi

# Configuration automatique du tunnel si le token est fourni
%{ if cloudflare_tunnel_token != "" }
echo "Configuration automatique du tunnel Cloudflare..."
cloudflared service install "${cloudflare_tunnel_token}"
systemctl enable cloudflared
systemctl start cloudflared
echo "Tunnel Cloudflare configuré et démarré automatiquement"
%{ else }
echo "INFO: Aucun token de tunnel fourni. Configurez manuellement avec:"
echo "  sudo cloudflared service install <TOKEN>"
%{ endif }

# Création du répertoire de l'application
echo "Création du répertoire application..."
mkdir -p /opt/hr-directory
mkdir -p /opt/hr-directory/static
mkdir -p /opt/hr-directory/templates

# Configuration de nginx
echo "Configuration de nginx..."
cat > /etc/nginx/sites-available/hr-directory << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    # Logs
    access_log /var/log/nginx/hr-directory-access.log;
    error_log /var/log/nginx/hr-directory-error.log;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_http_version 1.1;
        
        # Headers standards
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Headers Cloudflare Access (forward des headers JWT)
        proxy_set_header CF-Access-Authenticated-User-Email $http_cf_access_authenticated_user_email;
        proxy_set_header CF-Access-Authenticated-User-Id $http_cf_access_authenticated_user_id;
        proxy_set_header CF-Access-Jwt-Assertion $http_cf_access_jwt_assertion;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    location /static {
        alias /opt/hr-directory/static;
        expires 1d;
        add_header Cache-Control "public, immutable";
    }

    # Gestion des erreurs
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
EOF

# Activation du site nginx
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/hr-directory /etc/nginx/sites-enabled/

# Test de la configuration nginx
nginx -t

# Recharger nginx pour prendre en compte la nouvelle configuration
echo "Redémarrage de nginx..."
systemctl restart nginx

# Création du service systemd pour l'application Flask
echo "Création du service systemd..."
cat > /etc/systemd/system/hr-directory.service << 'EOF'
[Unit]
Description=HR Directory Flask Application
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/hr-directory
Environment="PATH=/opt/hr-directory/venv/bin"
Environment="PYTHONUNBUFFERED=1"
Environment="FLASK_ENV=production"

# Attendre que les fichiers soient déployés
ExecStartPre=/bin/sleep 5
ExecStartPre=/bin/bash -c 'while [ ! -f /opt/hr-directory/wsgi.py ]; do sleep 2; done'

ExecStart=/opt/hr-directory/venv/bin/gunicorn \
    --workers 2 \
    --bind 127.0.0.1:5000 \
    --access-logfile /var/log/hr-directory-access.log \
    --error-logfile /var/log/hr-directory-error.log \
    --capture-output \
    --enable-stdio-inheritance \
    wsgi:app

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Permissions
echo "Configuration des permissions..."
chown -R www-data:www-data /opt/hr-directory

# Création des fichiers de log avec les bonnes permissions
echo "Configuration des logs..."
touch /var/log/hr-directory-access.log /var/log/hr-directory-error.log
chown www-data:www-data /var/log/hr-directory-access.log /var/log/hr-directory-error.log
chmod 644 /var/log/hr-directory-access.log /var/log/hr-directory-error.log

# Rechargement systemd
systemctl daemon-reload

# Démarrage de nginx
systemctl enable nginx
systemctl start nginx

# Note: Le service hr-directory ne démarrera pas tant que les fichiers
# de l'application ne seront pas déployés (via deploy-app.sh)

echo "=== Installation terminée === $(date)"
echo "ATTENTION : Déployez les fichiers de l'application avec deploy-app.sh"
echo "Puis démarrez le service : sudo systemctl start hr-directory"
