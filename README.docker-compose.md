# ERPNext Docker Compose Deployment

A production-ready Docker Compose setup for ERPNext with **modular app selection**.

## ✨ Features

- 🎯 **Select which apps to install** - Choose from 8 optional apps
- 🚀 **Production-ready** - Includes HTTPS, worker queues, scheduler
- 🔒 **Secure** - SSL/TLS encryption, isolated networks
- 📦 **Complete stack** - MariaDB, Redis, Nginx, all configured
- 🎨 **Flexible** - Use official image or custom-built image
- 📚 **Well documented** - Comprehensive guides included

## 📦 What's Included

### Core Services
- MariaDB 10.6 (database)
- Redis (cache, queue, socketio)
- Nginx (HTTPS reverse proxy)

### Application Services
- Backend (Gunicorn)
- WebSocket (Socket.IO)
- Queue Workers (default, short, long)
- Scheduler (background jobs)

### Available Apps
✅ ERPNext (always installed)  
➕ HRMS - Human Resources  
➕ CRM - Customer Relations  
➕ Helpdesk - Support Tickets  
➕ Insights - Analytics  
➕ Gameplan - Project Management  
➕ LMS - Learning Management  
➕ Healthcare - Medical Practice  
➕ Lending - Loan Management  

## 🚀 Quick Start

```bash
# 1. Configure
cp .env.example .env
nano .env  # Set passwords and select apps

# 2. Deploy
docker-compose up -d

# 3. Access (after 2-5 minutes)
https://localhost
```

**Default credentials:**
- Username: Administrator
- Password: (what you set in `.env`)

## 📖 Documentation

- **[Quick Start Guide](DOCKER_COMPOSE_QUICKSTART.md)** - Get running in 5 minutes
- **[Complete Guide](DOCKER_COMPOSE_GUIDE.md)** - Full documentation with examples
- **[Dockerfile](Dockerfile)** - Build custom images with all apps

## 🎯 App Selection

Choose which apps to install by editing [`.env`](.env.example):

```bash
# Uncomment the apps you want
INSTALL_HRMS=true
INSTALL_CRM=true
# INSTALL_HELPDESK=true
# etc.
```

**Important**: The apps must be included in your Docker image to be installed. See the guides for details.

## 🏗️ Architecture

```
┌─────────────┐
│   Nginx     │ :80, :443 (HTTPS)
│  (Frontend) │
└──────┬──────┘
       │
   ┌───┴────┐
   │        │
┌──▼───┐ ┌─▼────────┐
│Backend│ │ WebSocket│
└───┬──┘ └────┬─────┘
    │         │
┌───┴─────────┴──┐
│  Redis x3      │
│ (Cache/Queue)  │
└────────────────┘
         │
    ┌────▼────┐
    │ MariaDB │
    └─────────┘
```

## 🔧 Configuration Options

| Setting | Description | Default |
|---------|-------------|---------|
| `ERPNEXT_IMAGE` | Docker image to use | `frappe/erpnext:v15.75.1` |
| `SITE_NAME` | Internal site name | `frontend` |
| `ADMIN_PASSWORD` | Admin password | `admin123` ⚠️ Change this! |
| `DB_ROOT_PASSWORD` | Database password | Required ⚠️ |
| `HTTP_PORT` | HTTP port | `80` |
| `HTTPS_PORT` | HTTPS port | `443` |
| `INSTALL_*` | Install specific app | Commented out |

## 📝 Common Tasks

### View Logs
```bash
docker-compose logs -f
```

### Access Shell
```bash
docker-compose exec backend bash
```

### Backup
```bash
docker-compose exec backend bench --site frontend backup
```

### Restart
```bash
docker-compose restart
```

### Stop & Remove (keeps data)
```bash
docker-compose down
```

### Reset Everything
```bash
docker-compose down -v
```

## 🆚 vs Nomad Deployment

| Feature | Docker Compose | Nomad |
|---------|---------------|--------|
| Complexity | Simple | Advanced |
| Multi-node | No | Yes |
| Load balancing | No | Yes |
| Auto-scaling | No | Yes |
| Best for | Single server | Cluster/Production |

## 🔗 Related Files

- [`docker-compose.yml`](docker-compose.yml) - Main deployment file
- [`.env.example`](.env.example) - Configuration template
- [`Dockerfile`](Dockerfile) - Custom image builder
- [`erpnext-production.nomad`](erpnext-production.nomad) - Nomad deployment

## 📚 Resources

- [ERPNext Documentation](https://docs.erpnext.com/)
- [Frappe Framework](https://frappeframework.com/)
- [Docker Compose Docs](https://docs.docker.com/compose/)

## ⚠️ Production Considerations

For production use:
1. ✅ Use strong passwords
2. ✅ Use proper SSL certificates (not self-signed)
3. ✅ Set up regular backups
4. ✅ Monitor resource usage
5. ✅ Update images regularly
6. ✅ Use a proper domain name
7. ✅ Consider using Nomad for multi-server setups

## 🐛 Troubleshooting

See [`DOCKER_COMPOSE_GUIDE.md`](DOCKER_COMPOSE_GUIDE.md#-troubleshooting) for detailed troubleshooting steps.

Quick fixes:
```bash
# Check status
docker-compose ps

# View logs
docker-compose logs -f create-site

# Reset everything
docker-compose down -v && docker-compose up -d
```

## 📄 License

This configuration follows ERPNext's licensing (GNU GPL v3).

---

**Need help?** Check the [Complete Guide](DOCKER_COMPOSE_GUIDE.md) or [Quick Start](DOCKER_COMPOSE_QUICKSTART.md).