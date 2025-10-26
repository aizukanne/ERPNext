# 🚀 ERPNext Full Stack Deployment

[![ERPNext](https://img.shields.io/badge/ERPNext-v15.75.1-blue)](https://erpnext.com/)
[![Docker](https://img.shields.io/badge/Docker-Ready-brightgreen)](https://www.docker.com/)
[![License](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

A complete, production-ready deployment package for ERPNext with **all major apps** and **multiple deployment options**.

## 📋 What's Included

This repository contains everything you need to deploy ERPNext with a full suite of applications:

### 🎯 Core Apps (Always Included)
- **Frappe** - The framework powering it all
- **ERPNext** - Complete ERP system

### ✨ Optional Apps (Choose What You Need)
- **HRMS** - Human Resources Management
- **CRM** - Customer Relationship Management
- **Helpdesk** - Support Ticket System
- **Insights** - Business Intelligence & Analytics
- **Gameplan** - Project Management
- **LMS** - Learning Management System
- **Healthcare** - Medical Practice Management
- **Lending** - Loan Management System

### 🏗️ Infrastructure Components
- MariaDB 10.6 (Database)
- Redis 6.2 (Cache, Queue, SocketIO)
- Nginx (HTTPS Reverse Proxy)
- Gunicorn (Application Server)
- Worker Queues (Background Jobs)
- Scheduler (Cron Jobs)

## 🚀 Quick Start

Choose your deployment method:

### Option 1: Docker Compose (Recommended for Most Users)

**Perfect for:** Single server, development, small-medium businesses

```bash
# 1. Clone this repository
git clone <your-repo-url>
cd ERPNext

# 2. Configure
cp .env.example .env
nano .env  # Set passwords and select apps

# 3. Deploy
docker-compose up -d

# 4. Access (after 2-5 minutes)
# https://localhost
# Username: Administrator
# Password: (what you set in .env)
```

📖 **Guides:**
- [Quick Start](DOCKER_COMPOSE_QUICKSTART.md) - 5-minute setup
- [Cloud Deployment](CLOUD_DEPLOYMENT.md) - AWS & GCP guide

### Option 2: Nomad (Advanced)

**Perfect for:** Multi-server clusters, enterprise deployments, high availability

```bash
# 1. Build custom image
docker build -t erpnext-full:latest .

# 2. Update nomad job file
nano erpnext-production.nomad

# 3. Deploy
nomad job run erpnext-production.nomad
```

📖 **Full Guide:** [Nomad Deployment Guide](DEPLOYMENT.md)

## 📚 Documentation

### 🎯 Start Here
- **[INDEX.md](INDEX.md)** - Complete documentation index
- **[ANSWERS.md](ANSWERS.md)** - Quick answers to common questions

### 🐳 Docker Compose Deployment
- **[Quick Start (5 min)](DOCKER_COMPOSE_QUICKSTART.md)** - Get running fast
- **[Complete Guide](DOCKER_COMPOSE_GUIDE.md)** - Full documentation
- **[Cloud Deployment](CLOUD_DEPLOYMENT.md)** - AWS & GCP deployment
- **[Let's Encrypt SSL](LETSENCRYPT_GUIDE.md)** - Automatic SSL certificates
- **[Overview](README.docker-compose.md)** - Features and architecture

### 🎪 Nomad Deployment
- **[Deployment Guide](DEPLOYMENT.md)** - Step-by-step instructions
- **[Architecture](ARCHITECTURE_EXPLAINED.md)** - Why 12 containers?
- **[Network Config](NETWORK_CONFIGURATION.md)** - Networking details

### 🔧 Operations
- **[Quick Reference](QUICK_REFERENCE.md)** - Common commands
- **[Troubleshooting](TROUBLESHOOTING.md)** - Fix common issues

## ⚡ Features

### 🎨 Modular App Selection
Choose exactly which apps you need - don't install everything if you don't need it!

```bash
# Example: Install only HRMS and CRM
INSTALL_HRMS=true
INSTALL_CRM=true
```

### 🔒 Production Ready
- ✅ HTTPS with SSL/TLS encryption
- ✅ Proper service isolation
- ✅ Health checks and monitoring
- ✅ Automated backups possible
- ✅ Worker queues for background jobs
- ✅ Redis caching for performance

### 🎯 Two Deployment Options
| Feature | Docker Compose | Nomad |
|---------|---------------|--------|
| Setup Time | 5 minutes | 30 minutes |
| Complexity | Simple | Advanced |
| Best For | Single server | Multi-server cluster |
| Auto-scaling | No | Yes |
| Load balancing | No | Yes |

### 📦 Complete Stack
- 12 microservices working together
- Automated configuration
- Service discovery (Nomad)
- Volume management
- Log aggregation ready

## 🎯 Use Cases

### Small Business
```bash
# ERPNext + HRMS + CRM
INSTALL_HRMS=true
INSTALL_CRM=true
```

### Healthcare Organization
```bash
# ERPNext + HRMS + Healthcare
INSTALL_HRMS=true
INSTALL_HEALTHCARE=true
```

### Educational Institution
```bash
# ERPNext + HRMS + LMS + Helpdesk
INSTALL_HRMS=true
INSTALL_LMS=true
INSTALL_HELPDESK=true
```

### Financial Services
```bash
# ERPNext + HRMS + CRM + Lending
INSTALL_HRMS=true
INSTALL_CRM=true
INSTALL_LENDING=true
```

## 🏗️ Architecture

```
┌─────────────────────────────────────────┐
│           Nginx Frontend                │
│         (HTTPS Port 443)                │
└──────────────┬──────────────────────────┘
               │
       ┌───────┴────────┐
       │                │
┌──────▼──────┐  ┌─────▼────────┐
│   Backend   │  │  WebSocket   │
│ (Gunicorn)  │  │ (Socket.IO)  │
└──────┬──────┘  └──────┬───────┘
       │                │
       └────────┬───────┘
                │
    ┌───────────┴────────────┐
    │                        │
┌───▼────┐  ┌────▼─────┐  ┌─▼─────┐
│ Redis  │  │  Redis   │  │ Redis │
│ Cache  │  │  Queue   │  │Socket │
└────────┘  └──────────┘  └───────┘
                │
         ┌──────┴──────┐
         │             │
    ┌────▼───┐   ┌────▼────┐
    │Workers │   │Scheduler│
    └────┬───┘   └─────────┘
         │
    ┌────▼─────┐
    │ MariaDB  │
    │(Database)│
    └──────────┘
```

## 💻 System Requirements

### Minimum
- **CPU:** 2 cores
- **RAM:** 4 GB
- **Storage:** 20 GB
- **OS:** Linux with Docker

### Recommended
- **CPU:** 4+ cores
- **RAM:** 8+ GB (16 GB for all apps)
- **Storage:** 50+ GB SSD
- **OS:** Ubuntu 22.04 LTS or similar

### For Production
- **CPU:** 8+ cores
- **RAM:** 16+ GB
- **Storage:** 100+ GB SSD with backup
- **Network:** Dedicated server with proper firewall

## 🔧 Configuration

### Environment Variables

Key settings in `.env` file:

```bash
# Image Selection
ERPNEXT_IMAGE=frappe/erpnext:v15.75.1

# Site Configuration
SITE_NAME=frontend
DOMAIN_NAME=erp.yourcompany.com

# Security
ADMIN_PASSWORD=YourSecurePassword123!
DB_ROOT_PASSWORD=YourDatabasePassword123!

# Network
HTTP_PORT=80
HTTPS_PORT=443

# App Selection (uncomment to install)
# INSTALL_HRMS=true
# INSTALL_CRM=true
# etc.
```

## 🐛 Troubleshooting

### Quick Fixes

**Can't access site?**
```bash
docker-compose ps  # Check if services are running
docker-compose logs -f  # View logs
```

**Build failed?**
```bash
# Check Dockerfile fixes are applied
grep "skip-assets" Dockerfile  # Should show results

# Clean build
docker build --no-cache -t erpnext-full:latest .
```

**Need to reset?**
```bash
docker-compose down -v  # Remove everything including data
docker-compose up -d    # Start fresh
```

### Full Troubleshooting
See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed solutions.

## 📖 Learning Resources

### Official Documentation
- [ERPNext Documentation](https://docs.erpnext.com/)
- [Frappe Framework Docs](https://frappeframework.com/docs)
- [ERPNext Forum](https://discuss.erpnext.com/)

### Video Tutorials
- [ERPNext YouTube Channel](https://www.youtube.com/c/erpnext)

### Community
- [ERPNext Forum](https://discuss.erpnext.com/)
- [Frappe GitHub](https://github.com/frappe)

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📝 Version Information

- **ERPNext Version:** v15.75.1
- **Frappe Version:** v15 (included in ERPNext image)
- **MariaDB:** 10.6
- **Redis:** 6.2-alpine
- **Python:** 3.11

### App Versions
- **HRMS:** version-15 branch
- **CRM:** main branch
- **Helpdesk:** main branch
- **Insights:** main branch
- **Gameplan:** main branch
- **LMS:** main branch
- **Healthcare:** version-15 branch
- **Lending:** version-15 branch

## ⚠️ Important Notes

### Security
- 🔒 Change default passwords before deployment
- 🔒 Use proper SSL certificates in production (not self-signed)
- 🔒 Keep Docker images updated
- 🔒 Implement proper firewall rules
- 🔒 Regular security audits recommended

### Backups
- 💾 Set up automated backups
- 💾 Test restore procedures regularly
- 💾 Store backups off-site
- 💾 Document backup/restore process

### Production Deployment
- ⚡ Use proper domain names
- ⚡ Configure DNS properly
- ⚡ Set up monitoring
- ⚡ Plan for scaling
- ⚡ Have disaster recovery plan

## 📄 License

This deployment configuration is provided as-is. ERPNext and its apps are licensed under GNU General Public License v3.0.

- **ERPNext License:** [GNU GPL v3](https://github.com/frappe/erpnext/blob/develop/license.txt)
- **Frappe License:** [MIT](https://github.com/frappe/frappe/blob/develop/license.txt)

## 🆘 Support

### Documentation Issues
If you find issues with this deployment package:
1. Check existing documentation
2. Review troubleshooting guides
3. Search GitHub issues
4. Create a new issue with details

### ERPNext Issues
For ERPNext application issues:
- [ERPNext GitHub Issues](https://github.com/frappe/erpnext/issues)
- [ERPNext Forum](https://discuss.erpnext.com/)

### Professional Support
For professional ERPNext support and customization:
- [Frappe Cloud](https://frappecloud.com/)
- [ERPNext Partners](https://erpnext.com/service-providers)

## 🎉 Acknowledgments

- **Frappe Technologies** - For creating ERPNext and the Frappe Framework
- **ERPNext Community** - For continuous improvements and support
- **Docker Community** - For containerization best practices

---

## 📞 Quick Links

| Resource | Link |
|----------|------|
| 📖 Main Documentation | [INDEX.md](INDEX.md) |
| 🐳 Docker Compose Quick Start | [DOCKER_COMPOSE_QUICKSTART.md](DOCKER_COMPOSE_QUICKSTART.md) |
| 🎪 Nomad Deployment | [DEPLOYMENT.md](DEPLOYMENT.md) |
| ❓ FAQ | [ANSWERS.md](ANSWERS.md) |
| 🐛 Troubleshooting | [TROUBLESHOOTING.md](TROUBLESHOOTING.md) |
| 🏗️ Architecture | [ARCHITECTURE_EXPLAINED.md](ARCHITECTURE_EXPLAINED.md) |

---

**Ready to deploy ERPNext? Choose your path:**

- 🚀 **Quick & Easy:** [Docker Compose](DOCKER_COMPOSE_QUICKSTART.md)
- 🎯 **Enterprise:** [Nomad Cluster](DEPLOYMENT.md)

**Need help? Start with [INDEX.md](INDEX.md) or [ANSWERS.md](ANSWERS.md)**

---

Made with ❤️ for the ERPNext community