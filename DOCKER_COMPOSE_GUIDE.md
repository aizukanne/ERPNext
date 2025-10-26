# ERPNext Docker Compose Deployment Guide

This guide explains how to deploy ERPNext using Docker Compose with modular app selection.

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [App Selection](#app-selection)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Managing Your Installation](#managing-your-installation)
- [Troubleshooting](#troubleshooting)
- [Architecture](#architecture)

## 🎯 Overview

This Docker Compose setup allows you to:
- Deploy ERPNext with all its dependencies
- **Select which apps to install** (HRMS, CRM, Helpdesk, etc.)
- Use either the official ERPNext image or your custom-built image
- Run with production-ready configuration including HTTPS

### Available Apps

After ERPNext (always installed), you can choose from:
- **HRMS** - Human Resources Management System
- **CRM** - Customer Relationship Management
- **Helpdesk** - Support Ticket System
- **Insights** - Business Intelligence & Analytics
- **Gameplan** - Project Management
- **LMS** - Learning Management System
- **Healthcare** - Medical Practice Management
- **Lending** - Loan Management System

## 🔧 Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- Minimum 4GB RAM (8GB+ recommended for multiple apps)
- 20GB+ free disk space

## 🚀 Quick Start

### 1. Setup Configuration

Copy the example environment file and customize it:

```bash
cp .env.example .env
nano .env  # or use your preferred editor
```

### 2. Choose Your Apps

Edit `.env` and uncomment the apps you want to install:

```bash
# Example: Install only HRMS and CRM
INSTALL_HRMS=true
INSTALL_CRM=true
```

### 3. Set Passwords

**IMPORTANT**: Change the default passwords in `.env`:

```bash
ADMIN_PASSWORD=YourSecureAdminPassword
DB_ROOT_PASSWORD=YourSecureDatabasePassword
```

### 4. Deploy

```bash
# Start all services
docker-compose up -d

# Watch the logs (optional)
docker-compose logs -f
```

### 5. Access ERPNext

After 2-3 minutes (first startup takes longer):
- **HTTPS**: https://localhost
- **HTTP**: http://localhost (redirects to HTTPS)
- **Username**: Administrator
- **Password**: What you set in `.env` as `ADMIN_PASSWORD`

## 🎨 App Selection

### Option 1: Use Official Image (Requires Custom Dockerfile)

If using the official `frappe/erpnext:v15.75.1` image, you need to build a custom image with your desired apps first.

**Step 1**: Edit `Dockerfile` to include only the apps you want:

```dockerfile
# Example: Only install HRMS and CRM
RUN bench get-app --branch version-15 --skip-assets hrms https://github.com/frappe/hrms
RUN bench get-app --branch main --skip-assets crm https://github.com/frappe/crm

# Remove or comment out apps you don't need
# RUN bench get-app --branch main --skip-assets helpdesk ...
```

**Step 2**: Build your custom image:

```bash
docker build -t my-erpnext:v15 .
```

**Step 3**: Update `.env` to use your image:

```bash
ERPNEXT_IMAGE=my-erpnext:v15
```

**Step 4**: Update `.env` to install the apps:

```bash
INSTALL_HRMS=true
INSTALL_CRM=true
```

### Option 2: Pre-built Image with All Apps

If you've built an image with all apps included (using the provided Dockerfile):

**Step 1**: Use your image in `.env`:

```bash
ERPNEXT_IMAGE=your-registry/erpnext-full:latest
```

**Step 2**: Select which apps to install in `.env`:

```bash
# Uncomment only the apps you want
INSTALL_HRMS=true
INSTALL_CRM=true
INSTALL_HELPDESK=true
# etc.
```

### Option 3: Install Only ERPNext

To install just ERPNext without any additional apps:

```bash
# Leave all INSTALL_* variables commented out in .env
# INSTALL_HRMS=true   <-- Keep commented
# INSTALL_CRM=true    <-- Keep commented
# etc.
```

## ⚙️ Configuration

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `ERPNEXT_IMAGE` | Docker image to use | `frappe/erpnext:v15.75.1` | Yes |
| `SITE_NAME` | Site name (internal) | `frontend` | Yes |
| `DOMAIN_NAME` | Domain for SSL cert | `localhost` | No |
| `ADMIN_PASSWORD` | Administrator password | `admin123` | Yes |
| `DB_ROOT_PASSWORD` | Database root password | - | Yes |
| `HTTP_PORT` | HTTP port (redirects to HTTPS) | `80` | No |
| `HTTPS_PORT` | HTTPS port | `443` | No |
| `INSTALL_*` | Install specific app | - | No |

### Custom Ports

To use different ports (e.g., if 80/443 are taken):

```bash
HTTP_PORT=8080
HTTPS_PORT=8443
```

Then access at: https://localhost:8443

### Custom Domain

For a production domain:

```bash
DOMAIN_NAME=erp.mycompany.com
```

**Note**: The docker-compose setup generates a self-signed certificate. For production, you should:
1. Use Let's Encrypt certificates
2. Place them in the `ssl-certs` volume
3. Update the nginx configuration accordingly

## 🚢 Deployment

### First Time Deployment

```bash
# 1. Configure .env file
cp .env.example .env
nano .env

# 2. Start services
docker-compose up -d

# 3. Monitor site creation (takes 2-5 minutes)
docker-compose logs -f create-site

# 4. Once complete, access the site
# https://localhost
```

### Verify Deployment

```bash
# Check all services are running
docker-compose ps

# Should show all services as "Up" or "Exit 0" for one-time tasks
```

### Update Configuration

To add or remove apps after initial deployment:

**⚠️ WARNING**: This creates a NEW site and LOSES existing data!

```bash
# 1. Stop services
docker-compose down

# 2. Remove site data
docker volume rm erpnext_sites-data

# 3. Update .env with new app selection
nano .env

# 4. Start services
docker-compose up -d
```

## 🔧 Managing Your Installation

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f backend
docker-compose logs -f mariadb
```

### Access Backend Shell

```bash
docker-compose exec backend bash

# Then run bench commands
bench --site frontend console
bench --site frontend migrate
```

### Backup Your Data

```bash
# Backup site
docker-compose exec backend bench --site frontend backup

# Backups stored in: /home/frappe/frappe-bench/sites/frontend/private/backups
```

### Restore Backup

```bash
docker-compose exec backend bench --site frontend restore /path/to/backup.sql.gz
```

### Stop Services

```bash
# Stop (preserves data)
docker-compose stop

# Stop and remove containers (preserves volumes)
docker-compose down

# Stop and remove everything including data
docker-compose down -v
```

### Restart Services

```bash
# Restart all
docker-compose restart

# Restart specific service
docker-compose restart backend
```

## 🐛 Troubleshooting

### Site Not Accessible

```bash
# Check if all services are healthy
docker-compose ps

# Check backend logs
docker-compose logs backend

# Check if site was created
docker-compose logs create-site
```

### Database Connection Issues

```bash
# Check MariaDB is running
docker-compose logs mariadb

# Verify health check
docker-compose exec mariadb mysqladmin ping -p
```

### App Installation Failed

```bash
# Check create-site logs
docker-compose logs create-site

# Common issue: Image doesn't have the app
# Solution: Build custom image with the app included
```

### Reset Everything

```bash
# Stop and remove all containers and volumes
docker-compose down -v

# Rebuild (if using custom image)
docker build -t my-erpnext:v15 .

# Start fresh
docker-compose up -d
```

### Permission Errors

```bash
# Fix volume permissions
docker-compose exec backend chown -R frappe:frappe /home/frappe/frappe-bench/sites
```

### SSL Certificate Issues

The setup uses self-signed certificates. Your browser will show a warning - this is expected.

For production:
1. Get proper SSL certificates (Let's Encrypt recommended)
2. Mount them in the frontend service
3. Update nginx configuration

## 🏗️ Architecture

The deployment consists of:

### Core Services
- **mariadb**: Database (MariaDB 10.6)
- **redis-cache**: Caching layer
- **redis-queue**: Background job queue
- **redis-socketio**: Real-time communication

### Application Services
- **configurator**: One-time setup (creates common_site_config.json)
- **create-site**: One-time site creation and app installation
- **backend**: Gunicorn application server (port 8000)
- **websocket**: Socket.IO server for real-time features (port 9000)
- **frontend**: Nginx reverse proxy with HTTPS (ports 80, 443)

### Worker Services
- **queue-default**: Default queue processor
- **queue-short**: Short tasks processor
- **queue-long**: Long tasks processor
- **scheduler**: Scheduled job runner

### Network
All services communicate via the `erpnext-network` bridge network.

### Volumes
- `mariadb-data`: Database files
- `redis-*-data`: Redis persistence
- `sites-data`: ERPNext sites and files
- `logs-data`: Application logs
- `ssl-certs`: SSL certificates

## 📚 Additional Resources

- [ERPNext Documentation](https://docs.erpnext.com/)
- [Frappe Framework Docs](https://frappeframework.com/docs)
- [Docker Compose Docs](https://docs.docker.com/compose/)

## 🆘 Getting Help

If you encounter issues:

1. Check the logs: `docker-compose logs -f`
2. Verify all services are healthy: `docker-compose ps`
3. Review this guide's troubleshooting section
4. Check ERPNext community forums
5. Review GitHub issues for the specific app

## 📝 Example Configurations

### Example 1: Small Business Setup (ERPNext + HRMS + CRM)

```bash
# .env
ERPNEXT_IMAGE=frappe/erpnext:v15.75.1  # or your custom image
SITE_NAME=mycompany
ADMIN_PASSWORD=SecurePassword123!
DB_ROOT_PASSWORD=DatabasePassword123!

INSTALL_HRMS=true
INSTALL_CRM=true
```

### Example 2: Healthcare Organization

```bash
# .env
ERPNEXT_IMAGE=your-registry/erpnext-full:latest
SITE_NAME=hospital
ADMIN_PASSWORD=HospitalAdmin123!
DB_ROOT_PASSWORD=HospitalDB123!

INSTALL_HRMS=true
INSTALL_HEALTHCARE=true
```

### Example 3: Educational Institution

```bash
# .env
ERPNEXT_IMAGE=your-registry/erpnext-full:latest
SITE_NAME=university
ADMIN_PASSWORD=EduAdmin123!
DB_ROOT_PASSWORD=EduDB123!

INSTALL_HRMS=true
INSTALL_LMS=true
INSTALL_HELPDESK=true
```

### Example 4: Full Stack Installation

```bash
# .env
ERPNEXT_IMAGE=your-registry/erpnext-full:latest
SITE_NAME=enterprise
ADMIN_PASSWORD=EnterpriseAdmin123!
DB_ROOT_PASSWORD=EnterpriseDB123!

INSTALL_HRMS=true
INSTALL_CRM=true
INSTALL_HELPDESK=true
INSTALL_INSIGHTS=true
INSTALL_GAMEPLAN=true
INSTALL_LMS=true
INSTALL_HEALTHCARE=true
INSTALL_LENDING=true
```

---

**Happy ERPNext Deployment! 🎉**