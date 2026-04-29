# HR Employee Directory - Cloudflare Access Lab

Lab de démonstration pour remplacer un VPN traditionnel par Cloudflare Access (Zero Trust Network Access).

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Utilisateur                                  │
│                     (Navigateur Web)                                 │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ HTTPS
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     Cloudflare Edge                                  │
│  ┌──────────────┐     ┌─────────────────┐     ┌─────────────────┐  │
│  │  Authentik   │────▶│ Cloudflare      │────▶│ Cloudflare      │  │
│  │    (IdP)     │     │ Access          │     │ Tunnel          │  │
│  └──────────────┘     │ - JWT Validation│     │ (cloudflared)   │  │
│                       │ - Policy Engine │     └────────┬────────┘  │
│                       └─────────────────┘              │           │
└────────────────────────────────────────────────────────┼───────────┘
                                                         │
                              Connexion sécurisée (outbound)
                                                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     GCP Compute Engine (e2-micro)                    │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │  cloudflared daemon                                           │ │
│  │  └─▶ Connecté au tunnel Cloudflare (pas de ports entrants)   │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                              │                                      │
│                              ▼                                      │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │  nginx (port 80)                                              │ │
│  │  └─▶ Forward vers localhost:5000                              │ │
│  │  └─▶ Passe les headers CF-Access-*                            │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                              │                                      │
│                              ▼                                      │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │  Flask App (Python)                                           │ │
│  │  ┌─────────────────────────────────────────────────────────┐ │ │
│  │  │  Routes:                                                │ │ │
│  │  │  - /              → Liste des employés                  │ │ │
│  │  │  - /employee/<id> → Détail employé                     │ │ │
│  │  │  - /profile       → Profil JWT (démonstration)          │ │ │
│  │  └─────────────────────────────────────────────────────────┘ │ │
│  │  ┌─────────────────────────────────────────────────────────┐ │ │
│  │  │  SQLite: 10 employés fictifs internationaux             │ │ │
│  │  └─────────────────────────────────────────────────────────┘ │ │
│  └───────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

## Prérequis

### Cloudflare
- [x] Compte Cloudflare avec domaine configuré (`dgcf.ovh`)
- [x] Organisation Cloudflare One configurée
- [x] Authentik connecté comme IdP dans Access

### GCP
- [x] Projet GCP avec billing activé
- [x] API Compute Engine activée
- [x] Compte de service avec permissions Compute Admin (ou équivalent)

### Local
- [x] Terraform >= 1.0
- [x] Clé SSH (éd25519 recommandé)
- [x] Votre IP publique (trouvez-la sur https://www.whatismyip.com/)

## Structure du Projet

```
.
├── README.md                    # Ce fichier
├── provider.tf                  # Configuration GCP provider
├── variables.tf                 # Variables Terraform
├── main.tf                      # Ressources GCP (VM, VPC, firewall)
├── outputs.tf                   # Outputs et instructions
├── terraform.tfvars.example     # Template de configuration
├── startup.sh                   # Script d'installation VM
├── deploy-app.sh               # Script de déploiement de l'app
└── app/                        # Application Flask
    ├── app.py                  # Application principale
    ├── wsgi.py                 # Entry point Gunicorn
    ├── requirements.txt        # Dépendances Python
    ├── static/
    │   └── style.css          # Styles CSS
    └── templates/              # Templates HTML
        ├── base.html
        ├── employees.html
        ├── employee_detail.html
        ├── profile.html
        └── error.html
```

## Déploiement

### Étape 1 : Configuration

Créez le fichier `terraform.tfvars` :

```bash
cp terraform.tfvars.example terraform.tfvars
```

Éditez-le avec vos valeurs :

```hcl
project_id     = "votre-projet-gcp"
my_ip          = "1.2.3.4"  # Votre IP publique
ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID... david@mac"
```

### Étape 2 : Déploiement Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

Notez l'IP publique affichée dans les outputs.

### Étape 3 : Déploiement Application

Attendez que l'installation automatique se termine (~5-10 min), puis :

```bash
./deploy-app.sh <VM_IP> [SSH_USERNAME]
```

Exemple :
```bash
./deploy-app.sh 34.140.123.45 david
```

### Étape 4 : Configuration Cloudflare Tunnel

1. **Créer le tunnel** :
   - Allez sur https://one.dash.cloudflare.com
   - Networks → Tunnels → Create a tunnel
   - Type : Cloudflared
   - Nom : `hr-directory-tunnel`
   - Copiez le token fourni

2. **Installer le tunnel sur la VM** :
   ```bash
   ssh david@<VM_IP>
   sudo cloudflared service install <TOKEN>
   ```

3. **Configurer le Public Hostname** :
   - Dans le dashboard du tunnel, ajoutez :
     - Subdomain : `hr`
     - Domain : `dgcf.ovh`
     - Type : HTTP
     - URL : `localhost:80`

### Étape 5 : Configuration Cloudflare Access

1. **Créer l'application** :
   - Access → Applications → Add an application
   - Type : Self-hosted
   - Application Name : `HR Directory`
   - Session Duration : 24 hours

2. **Configurer le domaine** :
   - Domain : `hr.dgcf.ovh`
   - Cliquez sur "Add public hostname"

3. **Configurer l'IdP** :
   - Sélectionnez Authentik comme fournisseur d'identité

4. **Créer la policy** :
   - Create a new policy
   - Name : `Allow Employees`
   - Action : Allow
   - Include rules :
     - Selector : Emails
     - Value : votre-email@domaine.com

5. **Finaliser** :
   - Next → Next → Save application

### Étape 6 : Test

Accédez à : `https://hr.dgcf.ovh`

Vous devriez :
1. Être redirigé vers Authentik pour l'authentification
2. Après connexion, voir le HR Directory
3. Pouvoir cliquer sur "My Profile" pour voir les informations JWT

## Fonctionnalités de l'Application

### Pages
- **/** : Liste des employés avec statistiques
- **/employee/<id>** : Détail d'un employé
- **/profile** : Informations JWT de l'utilisateur connecté
- **/api/employees** : API JSON (démo)
- **/health** : Health check

### Données
10 employés fictifs internationaux répartis dans :
- Engineering (Paris, Singapore, Bangalore, Tokyo, Dubai)
- HR (Madrid, São Paulo)
- Sales (Berlin)
- Marketing (Dublin)
- Executive (New York)

### Sécurité
- Pas de login/password dans l'application
- Authentification déléguée à Cloudflare Access
- Headers JWT lus automatiquement
- Firewall GCP : seul SSH (22) est ouvert, et uniquement depuis votre IP

## Démonstration des Concepts

### Zero Trust
L'application Flask n'a pas de système d'authentification interne. Elle fait confiance à Cloudflare Access pour vérifier l'identité via Authentik.

### JWT Forwarding
Dans `/profile`, l'application lit :
- `CF-Access-Authenticated-User-Email` : Email de l'utilisateur
- `CF-Access-Authenticated-User-Id` : UUID unique
- `CF-Access-Jwt-Assertion` : JWT complet

### Pas de Ports Ouverts
La VM n'a pas besoin de ports entrants (80/443). Tout le trafic passe par le tunnel cloudflared en sortie uniquement.

## Nettoyage

Pour détruire l'infrastructure :

```bash
terraform destroy
```

## Résolution de Problèmes

### SSH refuse la connexion
```bash
# Vérifiez que votre IP est correcte dans terraform.tfvars
gcloud compute firewall-rules list --filter="name:access-allow-ssh"
```

### L'application ne répond pas
```bash
# Sur la VM
sudo systemctl status hr-directory
sudo journalctl -u hr-directory -f
sudo tail -f /var/log/hr-directory-error.log
```

### Le tunnel ne fonctionne pas
```bash
# Sur la VM
sudo systemctl status cloudflared
sudo cloudflared tunnel list
sudo tail -f /var/log/syslog | grep cloudflared
```

### Headers JWT non présents
- Vérifiez que vous accédez via `https://hr.dgcf.ovh` et pas directement par IP
- Vérifiez dans `/profile` que les headers sont bien transmis par nginx

## Ressources

- [Cloudflare Access Docs](https://developers.cloudflare.com/cloudflare-one/applications/)
- [Cloudflare Tunnel Docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)

## Notes

- Ce lab utilise une VM e2-micro (free tier eligible si dans les limites)
- Les données SQLite sont réinitialisées à chaque redémarrage de la VM
- Le CIDR 10.1.0.0/24 est utilisé pour éviter les conflits avec d'autres déploiements
