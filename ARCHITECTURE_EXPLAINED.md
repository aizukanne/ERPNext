# ERPNext with All Apps - Architecture & Deployment Guide

## 🏗️ Understanding the Architecture

### Why 12 Containers? (Microservices Explained)

```
┌─────────────────────────────────────────────────────────────┐
│                    ERPNext Platform                          │
│  ALL APPS RUN HERE: ERPNext, HR, CRM, Helpdesk, Insights,  │
│  Gameplan, LMS, Healthcare, Lending                         │
└─────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┴───────────────────┐
        │     Application Components            │
        └───────────────────────────────────────┘

1. DATABASE (1 container)
   └─ MariaDB - Stores all data for all apps

2. CACHING/QUEUING (3 containers - Why separate?)
   ├─ Redis Cache - Fast data caching
   ├─ Redis Queue - Background job queue  
   └─ Redis SocketIO - Real-time WebSocket state
   
   Why 3 Redis? Separation of concerns:
   - Cache can be flushed without affecting jobs
   - Queue persistence separate from cache
   - SocketIO needs dedicated connection pool

3. APPLICATION LAYER (3 containers)
   ├─ Backend (Gunicorn)
   │  └─ ALL APPS RUN HERE (Python/Frappe apps)
   ├─ WebSocket (Node.js)
   │  └─ Real-time features for all apps
   └─ Frontend (Nginx)
      └─ Static files + reverse proxy + HTTPS

4. BACKGROUND WORKERS (3 containers - Why multiple?)
   ├─ Scheduler
   │  └─ Runs cron jobs for all apps
   ├─ Queue-short
   │  └─ Quick jobs (emails, notifications)
   └─ Queue-long
      └─ Long jobs (reports, bulk operations)
      
   Why separate workers? Prevents long jobs from blocking quick ones

5. INITIALIZATION (2 one-time containers)
   ├─ Configurator - Sets up config files
   └─ Create-site - Creates site + installs all apps
```

### Key Points:

✅ **Adding 8 more apps = SAME 12 containers**
- Apps are Python modules, not separate containers
- Backend, workers, and scheduler run ALL apps

✅ **This is best practice microservices architecture**
- Better scalability (can scale workers independently)
- Better reliability (one component failure doesn't crash everything)
- Better performance (specialized containers for specific tasks)

## 📦 Docker Volumes vs Host Volumes

### Why Manual Volume Creation Was Needed

**Host Volumes** (previous approach):
- More control and security
- Explicit paths on host filesystem
- Requires manual setup in Nomad client config
- Like telling Nomad: "Use THIS specific directory"

**Docker Volumes** (new approach):
- Automatically created by Docker
- Managed by Docker volume subsystem
- No pre-configuration needed
- Docker handles placement and lifecycle

### Comparison:

```
Docker Compose:
  volumes:
    - erpnext-data:/var/lib/mysql
  # Docker automatically creates volume

Nomad with Host Volumes (old way):
  volume "data" {
    type = "host"
    source = "erpnext-data"  # Must exist in Nomad config!
  }
  # Required pre-configuration in /etc/nomad.d/client.hcl

Nomad with Docker Volumes (new way):
  volume "data" {
    type = "docker"
    source = "erpnext-data"  # Docker creates automatically!
  }
  # No pre-configuration needed!
```

## 🎨 Installed Apps Summary

### Base Apps (Always Included)
1. **Frappe** - Framework (required)
2. **ERPNext** - Core ERP

### Additional Apps (8 apps added)
3. **HRMS** - Human Resources Management
4. **CRM** - Customer Relationship Management
5. **Helpdesk** - Support ticket system
6. **Insights** - Business intelligence & analytics
7. **Gameplan** - Project management
8. **LMS** - Learning Management System
9. **Healthcare** - Medical practice management
10. **Lending** - Loan management

**Total: 10 apps in the SAME containers**

## 🚀 Deployment Options

### Option 1: Build Custom Image Locally (Recommended)

Build once, deploy anywhere:

```bash
# 1. Create Dockerfile for custom image
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
EOF

# 2. Build the image
docker build -t erpnext-full:latest .

# 3. Push to your registry (optional but recommended)
docker tag erpnext-full:latest your-registry.com/erpnext-full:latest
docker push your-registry.com/erpnext-full:latest
```

### Option 2: Use Docker Hub

Push to Docker Hub for easy deployment:

```bash
# Tag for Docker Hub
docker tag erpnext-full:latest yourusername/erpnext-full:latest

# Login and push
docker login
docker push yourusername/erpnext-full:latest
```

### Option 3: Local Registry

Set up a local Docker registry accessible from your Nomad cluster.

## 📊 Resource Requirements

### With All 10 Apps Installed

```
Per Container:
┌──────────────┬──────┬────────┬──────────────┐
│ Container    │ CPU  │ Memory │ Purpose      │
├──────────────┼──────┼────────┼──────────────┤
│ MariaDB      │ 500m │ 1GB    │ Database     │
│ Redis x3     │ 200m │ 256MB  │ Cache/Queue  │
│ Backend      │ 2000m│ 4GB    │ All Apps     │
│ WebSocket    │ 200m │ 512MB  │ Real-time    │
│ Frontend     │ 500m │ 1GB    │ HTTPS/Proxy  │
│ Scheduler    │ 200m │ 512MB  │ Cron Jobs    │
│ Worker-short │ 1000m│ 2GB    │ Quick Jobs   │
│ Worker-long  │ 1000m│ 2GB    │ Long Jobs    │
├──────────────┼──────┼────────┼──────────────┤
│ TOTAL        │ 6.2  │ 12.5GB │              │
└──────────────┴──────┴────────┴──────────────┘

Recommended Host: 8 cores, 16GB RAM, 50GB disk
```

Note: Backend and workers need more resources because they run ALL apps.

## 🔒 HTTPS on Port 443

The frontend container:
1. Generates self-signed SSL certificate (or uses provided certs)
2. Configures Nginx for HTTPS on port 443
3. Redirects HTTP (80) to HTTPS (443)
4. Proxies to backend and websocket services

### Using Your Own Certificates

Replace self-signed certs with real ones:

```bash
# After deployment, copy your certs to the SSL volume
docker volume inspect erpnext_ssl_certs
# Copy certs to the volume location

# Or mount from host
# Add to Nomad job:
volume "ssl-certs" {
  type = "host"
  source = "erpnext-ssl"  # Configure in Nomad client
}
```

### Using Let's Encrypt (via Traefik)

If you have Traefik with Let's Encrypt:
- Traefik handles SSL automatically
- Update Traefik labels in job
- Remove self-signed cert generation

## 🎯 Why This Architecture?

### 1. Separation of Concerns
Each container does ONE thing well:
- Database? MariaDB container
- Caching? Redis containers  
- Application? Backend container
- Web server? Nginx container

### 2. Independent Scaling
```bash
# Need more workers? Scale just the workers:
group "workers" {
  count = 3  # Instead of 1
}

# Need more backend capacity? Scale just backend:
group "application" {
  count = 2  # Run 2 backend containers
}
```

### 3. Independent Updates
- Update MariaDB? Only restart database container
- Update ERPNext? Only restart app containers
- Change Nginx config? Only restart frontend

### 4. Fault Isolation
- Redis crash? Other services keep running
- Worker crash? Backend still serves requests
- Backend crash? Workers keep processing queue

### 5. Resource Optimization
- Database gets dedicated memory
- Workers get dedicated CPU
- Cache gets optimized I/O

## 🆚 Comparison: Monolith vs Microservices

### Monolithic (All-in-One Container)
```
┌────────────────────────────┐
│     One Big Container      │
│                            │
│  - MariaDB                 │
│  - Redis                   │
│  - Nginx                   │
│  - Gunicorn                │
│  - Workers                 │
│  - Scheduler               │
│                            │
│  All apps run here         │
└────────────────────────────┘

Problems:
❌ Can't scale components independently
❌ One failure crashes everything
❌ Resource contention
❌ Hard to update
```

### Microservices (This Deployment)
```
┌──────────┐ ┌──────────┐ ┌──────────┐
│ MariaDB  │ │  Redis   │ │  Redis   │
│          │ │  Cache   │ │  Queue   │
└──────────┘ └──────────┘ └──────────┘
      │            │            │
      └────────────┴────────────┘
                   │
      ┌────────────┴────────────┐
      │                         │
┌──────────┐ ┌──────────┐ ┌──────────┐
│ Backend  │ │ Frontend │ │ Workers  │
│ All Apps │ │  Nginx   │ │  x3      │
└──────────┘ └──────────┘ └──────────┘

Benefits:
✅ Independent scaling
✅ Fault isolation
✅ Resource optimization
✅ Easy updates
```

## 💡 Key Takeaways

1. **12 containers is OPTIMAL** for production ERPNext
2. **Adding apps doesn't add containers** - they run in existing ones
3. **Docker volumes eliminate manual setup** - much easier than before
4. **Microservices = Production Best Practice** - not over-engineering
5. **All apps accessible at https://<container-ip>:443** - single entry point

## 🎓 Learning Resources

- Frappe Framework Docs: https://frappeframework.com/docs
- Frappe Apps Repository: https://github.com/frappe
- 12-Factor App Methodology: https://12factor.net/
- Microservices Patterns: https://microservices.io/

## Next Steps

1. Read DEPLOYMENT.md for step-by-step deployment
2. Build custom image with all apps
3. Deploy to Nomad
4. Access at https://<container-ip>:443
