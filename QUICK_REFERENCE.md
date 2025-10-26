# ERPNext Nomad Quick Reference

## Pre-Deployment

```bash
# 1. Run setup script (as root)
sudo ./setup-volumes.sh

# 2. Edit Nomad client config if needed
sudo nano /etc/nomad.d/client.hcl

# 3. Restart Nomad client after config changes
sudo systemctl restart nomad

# 4. Update passwords in erpnext.nomad
nano erpnext.nomad
# Search for: changeme_admin_password
# Replace with secure password
```

## Deployment

```bash
# Validate job file
nomad job validate erpnext.nomad

# Plan deployment (dry run)
nomad job plan erpnext.nomad

# Deploy ERPNext
nomad job run erpnext.nomad

# Check job status
nomad job status erpnext

# Get allocation IDs
nomad job status erpnext
```

## Monitoring

```bash
# Check specific allocation
nomad alloc status <alloc-id>

# View logs (follow mode)
nomad alloc logs -f <alloc-id> <task-name>

# View create-site logs (initial setup)
nomad alloc logs <app-alloc-id> create-site

# View backend logs
nomad alloc logs -f <app-alloc-id> backend

# View frontend logs
nomad alloc logs -f <app-alloc-id> frontend

# View worker logs
nomad alloc logs -f <worker-alloc-id> queue-short
```

## Service Discovery

```bash
# List all services
nomad service list

# Check specific service
nomad service info erpnext-frontend
```

## Network Information

```bash
# On the Nomad client node:

# List Docker networks
docker network ls

# Inspect specific network
docker network inspect <network-id>

# List running containers
docker ps | grep erpnext

# Inspect container
docker inspect <container-id>
```

## Accessing Containers

```bash
# Execute command in container
nomad alloc exec <alloc-id> <task-name> <command>

# Interactive bash session
nomad alloc exec -i -t <alloc-id> backend /bin/bash

# Run bench commands
nomad alloc exec -i -t <alloc-id> backend bash
cd /home/frappe/frappe-bench
bench --site frontend migrate
bench --site frontend clear-cache
bench --site frontend list-apps
```

## Common Bench Commands

```bash
# Inside backend container:

# Migrate database
bench --site frontend migrate

# Clear cache
bench --site frontend clear-cache

# Rebuild assets
bench build

# Create new user
bench --site frontend add-user user@example.com

# List installed apps
bench --site frontend list-apps

# Install custom app
bench get-app <app-name>
bench --site frontend install-app <app-name>

# Console (Python shell)
bench --site frontend console

# Show site status
bench --site frontend doctor
```

## Scaling

```bash
# Edit erpnext.nomad and change count:
# group "workers" {
#   count = 3  # Increase workers
# }

# Apply changes
nomad job plan erpnext.nomad
nomad job run erpnext.nomad
```

## Restarting

```bash
# Restart entire job
nomad job stop erpnext
nomad job run erpnext.nomad

# Restart specific allocation
nomad alloc restart <alloc-id>

# Restart specific task in allocation
nomad alloc restart <alloc-id> <task-name>
```

## Backups

```bash
# Database backup (from MariaDB container)
nomad alloc exec <db-alloc-id> mariadb bash
mysqldump -u root -p'<password>' --all-databases > /var/lib/mysql/backup-$(date +%Y%m%d).sql

# Site backup (from backend container)
nomad alloc exec <app-alloc-id> backend bash
cd /home/frappe/frappe-bench
bench --site frontend backup --with-files

# Backup files are stored in:
# /opt/nomad-volumes/erpnext/sites/frontend/private/backups/
```

## Troubleshooting

```bash
# Check Nomad node status
nomad node status

# Check Docker status
sudo systemctl status docker

# View Nomad logs
sudo journalctl -u nomad -f

# Check disk space
df -h /opt/nomad-volumes/erpnext/

# Test database connection
nomad alloc exec <app-alloc-id> backend bash
mysql -h <mariadb-ip> -u root -p

# Test Redis connection
nomad alloc exec <app-alloc-id> backend bash
redis-cli -h <redis-ip> ping

# View container resource usage
docker stats $(docker ps -q --filter "name=erpnext")
```

## Accessing ERPNext

```bash
# Find node IP
nomad node status -self | grep IP

# Access URL (replace <node-ip> with actual IP)
http://<node-ip>:8080

# Default credentials (change these!)
Username: Administrator
Password: admin (or what you set in create-site task)
```

## Upgrading

```bash
# 1. Update image version in erpnext.nomad
nano erpnext.nomad
# Change: image = "frappe/erpnext:v15.75.1"
# To:     image = "frappe/erpnext:v16.0.0"

# 2. Plan and apply
nomad job plan erpnext.nomad
nomad job run erpnext.nomad

# 3. Migrations run automatically
# Check logs to confirm
nomad alloc logs <app-alloc-id> backend
```

## Uninstalling

```bash
# Stop and remove job
nomad job stop -purge erpnext

# Remove volumes (WARNING: deletes all data!)
sudo rm -rf /opt/nomad-volumes/erpnext/

# Clean up Docker
docker system prune -a --volumes
```

## Performance Tuning

```bash
# Increase resources in erpnext.nomad:
resources {
  cpu    = 2000  # Increase CPU
  memory = 4096  # Increase RAM
}

# Scale workers for better background processing:
group "workers" {
  count = 3  # More parallel workers
}

# Monitor resource usage:
nomad alloc status <alloc-id>
```

## Useful File Locations

```
Host volumes:
  /opt/nomad-volumes/erpnext/mariadb/       - Database files
  /opt/nomad-volumes/erpnext/sites/         - ERPNext site files
  /opt/nomad-volumes/erpnext/logs/          - Application logs

Inside containers:
  /home/frappe/frappe-bench/                - Bench directory
  /home/frappe/frappe-bench/sites/          - Sites directory
  /home/frappe/frappe-bench/sites/frontend/ - Default site
  /var/lib/mysql/                           - MariaDB data
```

## Getting Help

ERPNext:
- Documentation: https://docs.erpnext.com/
- Forum: https://discuss.erpnext.com/
- GitHub: https://github.com/frappe/erpnext

Nomad:
- Documentation: https://www.nomadproject.io/docs
- Forum: https://discuss.hashicorp.com/c/nomad/
- Tutorial: https://learn.hashicorp.com/nomad
