# ERPNext Docker Compose - Quick Start

## 🚀 Get Started in 5 Minutes

### 1. Configure

```bash
cp .env.example .env
nano .env
```

**Edit these REQUIRED values:**
```bash
ADMIN_PASSWORD=YourSecurePassword123!
DB_ROOT_PASSWORD=YourDatabasePassword123!
```

### 2. Select Apps (Optional)

**Uncomment the apps you want:**
```bash
# Example: Install HRMS and CRM
INSTALL_HRMS=true
INSTALL_CRM=true

# Leave others commented out if you don't need them
# INSTALL_HELPDESK=true
# INSTALL_INSIGHTS=true
# etc.
```

### 3. Deploy

```bash
docker-compose up -d
```

### 4. Wait & Access

**Wait 2-5 minutes for initial setup**, then access:
- URL: https://localhost
- Username: Administrator  
- Password: (what you set in `ADMIN_PASSWORD`)

---

## 📝 Common Commands

### View Status
```bash
docker-compose ps
```

### View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f backend
docker-compose logs -f create-site
```

### Restart
```bash
docker-compose restart
```

### Stop
```bash
# Stop (keeps data)
docker-compose stop

# Stop & remove containers (keeps data)
docker-compose down

# Stop & remove everything including data
docker-compose down -v
```

### Access Shell
```bash
docker-compose exec backend bash
```

### Backup
```bash
docker-compose exec backend bench --site frontend backup
```

---

## 🎯 App Selection Examples

### Just ERPNext
```bash
# .env - all INSTALL_* lines commented out
ADMIN_PASSWORD=admin123
DB_ROOT_PASSWORD=root123
```

### Small Business
```bash
INSTALL_HRMS=true
INSTALL_CRM=true
```

### Healthcare
```bash
INSTALL_HRMS=true
INSTALL_HEALTHCARE=true
```

### Education
```bash
INSTALL_HRMS=true
INSTALL_LMS=true
INSTALL_HELPDESK=true
```

### Everything
```bash
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

## ⚠️ Important Notes

1. **First startup takes 2-5 minutes** - be patient!
2. **HTTPS uses self-signed certificate** - browser will warn you (click "Advanced" → "Proceed")
3. **Change default passwords** in `.env` before deploying
4. **Apps must be in your Docker image** to be installed (see main guide)
5. **Changing apps requires recreating the site** (deletes data)

---

## 🐛 Quick Troubleshooting

### "Can't access site"
```bash
# Check if services are ready
docker-compose ps

# Check create-site finished
docker-compose logs create-site
```

### "App not found"
- Make sure your Docker image includes the app
- See `DOCKER_COMPOSE_GUIDE.md` for building custom images

### "Permission denied"
```bash
docker-compose exec backend chown -R frappe:frappe /home/frappe/frappe-bench/sites
```

### "Reset everything"
```bash
docker-compose down -v
docker-compose up -d
```

---

## 📖 Need More Help?

See the full guide: [`DOCKER_COMPOSE_GUIDE.md`](DOCKER_COMPOSE_GUIDE.md)