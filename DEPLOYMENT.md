# Complete ERPNext Deployment Guide
## With All Apps + HTTPS on Port 443 + Docker Volumes

This guide deploys ERPNext with 10 apps on Nomad with automatic volume creation.

## 📋 What You're Deploying

### Installed Apps (10 total)
1. **Frappe** - Framework (base)
2. **ERPNext** - ERP system
3. **HRMS** - Human Resources
4. **CRM** - Customer Relations
5. **Helpdesk** - Support tickets
6. **Insights** - Business intelligence
7. **Gameplan** - Project management
8. **LMS** - Learning management
9. **Healthcare** - Medical management
10. **Lending** - Loan management

### Infrastructure (12 containers)
- 1× MariaDB
- 3× Redis (cache, queue, socketio)
- 1× Backend (ALL 10 apps run here)
- 1× WebSocket
- 1× Frontend (HTTPS on port 443)
- 1× Scheduler
- 2× Workers (short, long)
- 2× Init containers (configurator, create-site)

### Access
- **HTTPS**: `https://<frontend-container-ip>`
- **HTTP**: Redirects to HTTPS
- **Default Port**: 443 (HTTPS)

## 🚀 Quick Start (3 Steps)

### Step 1: Build Custom Image

```bash
# 1. Save the Dockerfile
cat > Dockerfile <<'EOF'
FROM frappe/erpnext:v15.75.1

USER frappe
WORKDIR /home/frappe/frappe-bench

# Install all apps
RUN bench get-app --branch version-15 hrms https://github.com/frappe/hrms && \
    bench get-app --branch version-15 crm https://github.com/frappe/crm && \
    bench get-app --branch main helpdesk https://github.com/frappe/helpdesk && \
    bench get-app --branch main insights https://github.com/frappe/insights && \
    bench get-app --branch main gameplan https://github.com/frappe/gameplan && \
    bench get-app --branch main lms https://github.com/frappe/lms && \
    bench get-app --branch version-15 healthcare https://github.com/frappe/healthcare && \
    bench get-app --branch version-15 lending https://github.com/frappe/lending

# Build all assets
RUN bench build --apps frappe,erpnext,hrms,crm,helpdesk,insights,gameplan,lms,healthcare,lending

USER root
RUN chown -R frappe:frappe /home/frappe/frappe-bench
USER frappe
EOF

# 2. Build image (takes 15-30 minutes)
docker build -t erpnext-full:latest .

# 3a. Push to your registry (recommended)
docker tag erpnext-full:latest your-registry.com/erpnext-full:latest
docker push your-registry.com/erpnext-full:latest

# OR 3b. Push to Docker Hub
docker tag erpnext-full:latest yourusername/erpnext-full:latest
docker login
docker push yourusername/erpnext-full:latest
```

### Step 2: Update Nomad Job

Edit `erpnext-production.nomad`:

```bash
# Find and replace (4 places):
image = "your-registry/erpnext-full:latest"

# With your actual image:
image = "your-registry.com/erpnext-full:latest"
# or
image = "yourusername/erpnext-full:latest"
```

Update passwords:
```bash
# Find and replace ALL instances:
CHANGE_THIS_SECURE_PASSWORD → your_secure_db_password
CHANGE_ADMIN_PASSWORD → your_admin_password
```

### Step 3: Deploy

```bash
# Validate
nomad job validate erpnext-production.nomad

# Deploy
nomad job run erpnext-production.nomad

# Monitor (wait 5-10 minutes for initial setup)
nomad job status erpnext-full
```

## 🔍 Detailed Steps

### Prerequisites

✅ Docker installed on docker-server node
✅ Nomad cluster running with Consul
✅ Network `lan_routed_net` exists
✅ 16GB+ RAM, 8+ CPU cores available
✅ 50GB+ disk space

### Verify Network

```bash
# On docker-server node
docker network ls | grep lan_routed_net

# If doesn't exist, create it:
docker network create \
  --driver bridge \
  --subnet 172.20.0.0/16 \
  lan_routed_net
```

### Build Process Details

The image build installs 8 additional apps on top of ERPNext:

```
Base Image (frappe/erpnext:v15.75.1)
  ├── Frappe framework (included)
  └── ERPNext (included)
      
Install Apps (bench get-app):
  ├── HRMS
  ├── CRM  
  ├── Helpdesk
  ├── Insights
  ├── Gameplan
  ├── LMS
  ├── Healthcare
  └── Lending

Build Assets (bench build):
  └── Compiles JS/CSS for all 10 apps

Result: erpnext-full:latest (~3GB)
```

**Build time**: 15-30 minutes depending on CPU
**Image size**: ~3GB
**Build frequency**: Only when apps need updating

### Understanding Docker Volumes

The job uses Docker volumes (not host volumes):

```hcl
volume "sites" {
  type   = "docker"     # Managed by Docker
  source = "erpnext_sites"  # Docker creates this
}
```

**Advantages**:
✅ No manual setup required
✅ Docker handles lifecycle
✅ Portable across hosts
✅ Automatic cleanup options

**Where are they stored?**
```bash
# Find volumes
docker volume ls | grep erpnext

# Inspect location
docker volume inspect erpnext_sites
# Typically: /var/lib/docker/volumes/erpnext_sites/_data
```

### Deployment Flow

```
1. Submit job → Nomad schedules on docker-server
                ↓
2. Database starts → MariaDB initializes
                ↓
3. Redis starts → 3 Redis instances ready
                ↓
4. Configurator runs → Sets up config files
                ↓
5. Create-site runs → Creates site + installs all 10 apps
                (takes 5-10 minutes)
                ↓
6. Backend starts → Serves all apps
                ↓
7. WebSocket starts → Real-time features
                ↓
8. Frontend starts → HTTPS on port 443
                ↓
9. Workers start → Background processing
                ↓
10. READY → Access at https://<container-ip>
```

### Monitoring Deployment

```bash
# Overall status
nomad job status erpnext-full

# Get allocation IDs
nomad job status erpnext-full

# Watch create-site (most important)
nomad alloc logs -f <app-alloc-id> create-site

# Expected output:
# Creating site...
# Installing erpnext...
# Installing hrms...
# Installing crm...
# ... (8 more apps)
# Site created with all apps installed
```

## 🌐 Accessing ERPNext

### Find Frontend IP

```bash
# Method 1: Via Nomad
nomad service info erpnext-frontend

# Method 2: Via Docker
docker ps | grep frontend
docker inspect <container-id> | grep IPAddress
```

### Access

1. **HTTPS** (recommended): `https://<frontend-ip>`
2. **HTTP**: `http://<frontend-ip>` (redirects to HTTPS)

### First Login

- **URL**: `https://<frontend-ip>`
- **Username**: `Administrator`
- **Password**: (what you set as CHANGE_ADMIN_PASSWORD)

### SSL Certificate

**Self-signed certificate** is generated automatically:
- Valid for 365 days
- Browser will show warning (accept it)
- Common Name: erp.yourdomain.com

**Use real certificate**:
```bash
# Get volume location
docker volume inspect erpnext_ssl_certs

# Copy your certificates
sudo cp your-cert.pem /var/lib/docker/volumes/erpnext_ssl_certs/_data/cert.pem
sudo cp your-key.pem /var/lib/docker/volumes/erpnext_ssl_certs/_data/key.pem

# Restart frontend
nomad alloc restart <app-alloc-id>
```

## 📱 Using the Apps

### Accessing Different Apps

All apps share the same interface. After logging in:

1. **ERPNext**: Default home
2. **HRMS**: Menu → HR
3. **CRM**: Menu → CRM
4. **Helpdesk**: Menu → Support
5. **Insights**: Menu → Insights
6. **Gameplan**: Menu → Projects
7. **LMS**: Menu → Education
8. **Healthcare**: Menu → Healthcare
9. **Lending**: Menu → Lending

### Initial Setup

```
First Login
  ↓
Setup Wizard runs
  ↓
Configure:
  - Language
  - Country/Currency
  - Company details
  - Chart of accounts
  - Financial year
  ↓
Select which apps to enable
  ↓
Start using ERPNext!
```

## 🔧 Configuration

### Resource Adjustments

If performance is slow:

```hcl
# Backend (runs all apps)
resources {
  cpu    = 4000  # Increase from 2000
  memory = 8192  # Increase from 4096
}

# Workers (process background jobs)
resources {
  cpu    = 2000  # Increase from 1000
  memory = 4096  # Increase from 2048
}
```

### Scaling Workers

```hcl
group "workers" {
  count = 2  # Run 2 sets of workers instead of 1
}
```

### Custom Domain

Update Traefik labels:
```hcl
tags = [
  "traefik.enable=true",
  "traefik.http.routers.erpnext.rule=Host(`erp.yourdomain.com`)",
  "traefik.http.routers.erpnext.tls=true",
]
```

## 💾 Backups

### Database Backup

```bash
# Exec into MariaDB
nomad alloc exec <db-alloc-id> mariadb bash

# Backup
mysqldump -u root -p'your_password' --all-databases > backup.sql

# Backup location
docker volume inspect erpnext_mariadb_data
```

### Site Backup (includes all apps)

```bash
# Exec into backend
nomad alloc exec <app-alloc-id> backend bash

# Backup site with all data
bench --site frontend backup --with-files

# Backup stored in
/home/frappe/frappe-bench/sites/frontend/private/backups/
```

### Volume Backup

```bash
# Backup volumes to tar files
docker run --rm \
  -v erpnext_sites:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/erpnext-sites-backup.tar.gz /data

# Repeat for other volumes
```

## 🔄 Updates

### Updating Apps

```bash
# 1. Rebuild image with latest app versions
docker build -t erpnext-full:latest .
docker push your-registry/erpnext-full:latest

# 2. Redeploy
nomad job run erpnext-production.nomad

# 3. Run migrations (automatic on restart)
# Or manually:
nomad alloc exec <app-alloc-id> backend bash
bench --site frontend migrate
```

### Updating ERPNext Version

```bash
# 1. Update Dockerfile
FROM frappe/erpnext:v16.0.0  # New version

# 2. Rebuild
docker build -t erpnext-full:latest .

# 3. Redeploy
nomad job run erpnext-production.nomad
```

## 🐛 Troubleshooting

### Site Creation Failed

```bash
# Check logs
nomad alloc logs <app-alloc-id> create-site

# Common: Database not ready
# Wait 30 seconds and try again
nomad alloc restart <app-alloc-id>
```

### Can't Access HTTPS

```bash
# Check frontend is running
nomad alloc logs <app-alloc-id> frontend

# Test connectivity
ping <frontend-ip>
telnet <frontend-ip> 443
```

### Apps Not Showing

```bash
# List installed apps
nomad alloc exec <app-alloc-id> backend bash
bench --site frontend list-apps

# If missing, reinstall
bench --site frontend install-app hrms
```

### High Memory Usage

```bash
# Check resource usage
nomad alloc status <alloc-id>

# Scale up resources in job file
# Or scale workers group count down
```

## 📊 Monitoring

### Health Checks

```bash
# All services
nomad service list | grep erpnext

# Specific service health
nomad service info erpnext-frontend
```

### Logs

```bash
# Backend (application logs)
nomad alloc logs -f <app-alloc-id> backend

# Workers (job processing)
nomad alloc logs -f <worker-alloc-id> queue-short

# Frontend (access logs)
nomad alloc logs -f <app-alloc-id> frontend
```

### Resource Usage

```bash
# Per allocation
nomad alloc status <alloc-id>

# Docker stats
docker stats $(docker ps -q --filter "name=erpnext")
```

## 🎓 Next Steps

1. ✅ Complete Setup Wizard
2. ✅ Create user accounts (Setup → Users)
3. ✅ Configure each app's settings
4. ✅ Set up backup automation
5. ✅ Configure SSL with real certificate
6. ✅ Set up monitoring/alerting
7. ✅ Plan for scaling
8. ✅ Train users on the platform

## 📚 Resources

- [Frappe Documentation](https://frappeframework.com/docs)
- [ERPNext User Manual](https://docs.erpnext.com/)
- [Frappe Apps](https://github.com/frappe)
- [Community Forum](https://discuss.erpnext.com/)

## 🔐 Security Checklist

- [ ] Change all default passwords
- [ ] Use real SSL certificates
- [ ] Enable firewall rules
- [ ] Regular backups configured
- [ ] Update plan in place
- [ ] User access controls set
- [ ] Database backup tested
- [ ] Disaster recovery plan

---

**Deployment Time**: ~30 minutes (including image build)
**Total Containers**: 12
**Apps Installed**: 10
**Access**: HTTPS on port 443
**Volumes**: Automatically managed by Docker
