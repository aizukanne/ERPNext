# Cloud Deployment Guide (AWS & GCP)

Complete guide for deploying ERPNext on AWS or Google Cloud Platform with proper security, networking, and SSL configuration.

## 📋 Table of Contents

- [Port Mappings & Security](#port-mappings--security)
- [AWS Deployment](#aws-deployment)
- [GCP Deployment](#gcp-deployment)
- [Post-Deployment Configuration](#post-deployment-configuration)
- [SSL Certificate Setup](#ssl-certificate-setup)
- [Monitoring & Maintenance](#monitoring--maintenance)
- [Cost Optimization](#cost-optimization)

---

## 🔒 Port Mappings & Security

### Services & Ports Overview

| Service | Internal Port | Exposed Port | Public Access | Notes |
|---------|--------------|--------------|---------------|-------|
| **Frontend (Nginx)** | 80, 443 | 80, 443 | ✅ **YES** | **ONLY service exposed publicly** |
| Backend (Gunicorn) | 8000 | - | ❌ NO | Internal only, accessed via Nginx |
| WebSocket (Socket.IO) | 9000 | - | ❌ NO | Internal only, proxied by Nginx |
| MariaDB | 3306 | - | ❌ NO | Database - never expose publicly |
| Redis Cache | 6379 | - | ❌ NO | Internal cache only |
| Redis Queue | 6379 | - | ❌ NO | Internal queue only |
| Redis SocketIO | 6379 | - | ❌ NO | Internal real-time only |
| Workers | - | - | ❌ NO | Background processing only |
| Scheduler | - | - | ❌ NO | Cron jobs only |

### 🎯 Critical Security Rule

**⚠️ ONLY expose ports 80 and 443 to the public internet!**

All other services communicate internally through Docker's private network. This architecture provides:
- ✅ **Security**: Database and Redis are never directly accessible
- ✅ **Simplicity**: One entry point for all traffic
- ✅ **Performance**: Internal network communication is faster
- ✅ **Best Practice**: Standard reverse proxy pattern

### Traffic Flow

```
Internet Users
     ↓
[Port 80/443] ← ONLY public ports
     ↓
Nginx Frontend (Reverse Proxy)
     ↓
     ├─→ Backend (8000) ← Internal
     ├─→ WebSocket (9000) ← Internal
     ↓
Redis Services (6379) ← Internal
     ↓
MariaDB (3306) ← Internal
```

---

## ☁️ AWS Deployment

### System Requirements

#### Minimum Configuration
- **Instance Type**: t3.medium
- **vCPUs**: 2
- **RAM**: 4 GB
- **Storage**: 50 GB EBS SSD
- **OS**: Ubuntu 22.04 LTS

#### Recommended Configuration
- **Instance Type**: t3.large or t3.xlarge
- **vCPUs**: 2-4
- **RAM**: 8-16 GB
- **Storage**: 100 GB EBS SSD (gp3)
- **OS**: Ubuntu 22.04 LTS

### Step 1: Launch EC2 Instance

#### Using AWS Console

1. **Navigate to EC2 Dashboard**
   - Services → EC2 → Launch Instance

2. **Configure Instance**
   ```
   Name: erpnext-production
   AMI: Ubuntu Server 22.04 LTS
   Instance Type: t3.large
   Key Pair: Create new or select existing
   ```

3. **Storage Configuration**
   ```
   Volume Type: gp3
   Size: 100 GB
   Delete on Termination: No (for data safety)
   ```

#### Using AWS CLI

```bash
# Create instance
aws ec2 run-instances \
  --image-id ami-0cd59ecaf368e5ccf \
  --instance-type t3.large \
  --key-name your-key-pair \
  --security-group-ids sg-xxxxx \
  --subnet-id subnet-xxxxx \
  --block-device-mappings '[
    {
      "DeviceName": "/dev/sda1",
      "Ebs": {
        "VolumeSize": 100,
        "VolumeType": "gp3",
        "DeleteOnTermination": false
      }
    }
  ]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=erpnext-production}]'
```

### Step 2: Configure Security Group

#### Required Rules

**Inbound Rules:**

| Type | Protocol | Port | Source | Description |
|------|----------|------|--------|-------------|
| SSH | TCP | 22 | Your IP/32 | Admin access only |
| HTTP | TCP | 80 | 0.0.0.0/0 | ACME challenge & redirect |
| HTTPS | TCP | 443 | 0.0.0.0/0 | Main application access |

**Outbound Rules:**
- All traffic allowed (default)

#### AWS Console Configuration

```
1. EC2 → Security Groups → Create Security Group
   Name: erpnext-sg
   Description: ERPNext security group
   VPC: Your VPC

2. Add Inbound Rules:
   - SSH: 22, Your IP (e.g., 203.0.113.0/32)
   - HTTP: 80, 0.0.0.0/0
   - HTTPS: 443, 0.0.0.0/0

3. Leave Outbound Rules as default (allow all)
```

#### AWS CLI Configuration

```bash
# Create security group
aws ec2 create-security-group \
  --group-name erpnext-sg \
  --description "ERPNext security group" \
  --vpc-id vpc-xxxxx

# Add SSH rule (restrict to your IP)
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxx \
  --protocol tcp \
  --port 22 \
  --cidr YOUR_IP/32

# Add HTTP rule
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxx \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

# Add HTTPS rule
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxx \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0
```

### Step 3: Allocate Elastic IP

#### Why Use Elastic IP?
- ✅ Static IP address (doesn't change on reboot)
- ✅ Easy DNS configuration
- ✅ Free when attached to running instance

#### Allocation Steps

```bash
# Allocate Elastic IP
aws ec2 allocate-address --domain vpc

# Output will show: AllocationId: eipalloc-xxxxx

# Associate with instance
aws ec2 associate-address \
  --instance-id i-xxxxx \
  --allocation-id eipalloc-xxxxx
```

### Step 4: Configure DNS

Point your domain to the Elastic IP:

**Route 53 (AWS DNS):**
```bash
# Create A record
aws route53 change-resource-record-sets \
  --hosted-zone-id Z123456789ABC \
  --change-batch '{
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "erp.yourcompany.com",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [{"Value": "YOUR_ELASTIC_IP"}]
      }
    }]
  }'
```

**External DNS Provider:**
```
Type: A
Name: erp (or @)
Value: YOUR_ELASTIC_IP
TTL: 300 (or default)
```

### Step 5: Install Docker & Deploy

```bash
# 1. SSH into instance
ssh -i your-key.pem ubuntu@YOUR_ELASTIC_IP

# 2. Update system
sudo apt update && sudo apt upgrade -y

# 3. Install Docker
sudo apt install -y docker.io docker-compose
sudo systemctl enable docker
sudo systemctl start docker

# 4. Add user to docker group
sudo usermod -aG docker ubuntu
newgrp docker

# 5. Clone repository
git clone <your-repo-url>
cd ERPNext

# 6. Configure environment
cp .env.example .env
nano .env

# Set:
DOMAIN_NAME=erp.yourcompany.com
USE_LETSENCRYPT=true
LETSENCRYPT_EMAIL=admin@yourcompany.com
ADMIN_PASSWORD=YourSecurePassword123!
DB_ROOT_PASSWORD=YourDatabasePassword123!

# 7. Deploy
docker-compose --profile production up -d

# 8. Monitor logs
docker-compose logs -f
```

### Step 6: Verify Deployment

```bash
# Check all services are running
docker-compose ps

# Check certificate acquisition
docker-compose logs certbot-init

# Test access
curl -I https://erp.yourcompany.com
```

---

## 🌐 GCP Deployment

### System Requirements

#### Minimum Configuration
- **Machine Type**: e2-standard-2
- **vCPUs**: 2
- **RAM**: 8 GB
- **Boot Disk**: 50 GB SSD
- **OS**: Ubuntu 22.04 LTS

#### Recommended Configuration
- **Machine Type**: e2-standard-4
- **vCPUs**: 4
- **RAM**: 16 GB
- **Boot Disk**: 100 GB SSD
- **OS**: Ubuntu 22.04 LTS

### Step 1: Create Compute Engine Instance

#### Using GCP Console

```
1. Compute Engine → VM Instances → Create Instance

2. Configure:
   Name: erpnext-production
   Region: us-central1 (choose closest to users)
   Zone: us-central1-a
   Machine type: e2-standard-4
   
3. Boot Disk:
   OS: Ubuntu 22.04 LTS
   Disk type: SSD persistent disk
   Size: 100 GB
   
4. Firewall:
   ☑ Allow HTTP traffic
   ☑ Allow HTTPS traffic
   
5. Network Tags: erpnext
```

#### Using gcloud CLI

```bash
# Create instance
gcloud compute instances create erpnext-production \
  --zone=us-central1-a \
  --machine-type=e2-standard-4 \
  --network-interface=network-tier=PREMIUM,subnet=default \
  --maintenance-policy=MIGRATE \
  --tags=erpnext,http-server,https-server \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=100GB \
  --boot-disk-type=pd-ssd
```

### Step 2: Configure Firewall Rules

#### Using GCP Console

```
1. VPC Network → Firewall → Create Firewall Rule

2. SSH Rule:
   Name: erpnext-ssh
   Targets: Specified target tags (erpnext)
   Source IP ranges: YOUR_IP/32
   Protocols/Ports: tcp:22

3. HTTP Rule:
   Name: erpnext-http
   Targets: Specified target tags (erpnext)
   Source IP ranges: 0.0.0.0/0
   Protocols/Ports: tcp:80

4. HTTPS Rule:
   Name: erpnext-https
   Targets: Specified target tags (erpnext)
   Source IP ranges: 0.0.0.0/0
   Protocols/Ports: tcp:443
```

#### Using gcloud CLI

```bash
# SSH rule (restrict to your IP)
gcloud compute firewall-rules create erpnext-ssh \
  --direction=INGRESS \
  --priority=1000 \
  --network=default \
  --action=ALLOW \
  --rules=tcp:22 \
  --source-ranges=YOUR_IP/32 \
  --target-tags=erpnext

# HTTP rule
gcloud compute firewall-rules create erpnext-http \
  --direction=INGRESS \
  --priority=1000 \
  --network=default \
  --action=ALLOW \
  --rules=tcp:80 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=erpnext

# HTTPS rule
gcloud compute firewall-rules create erpnext-https \
  --direction=INGRESS \
  --priority=1000 \
  --network=default \
  --action=ALLOW \
  --rules=tcp:443 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=erpnext
```

### Step 3: Reserve Static IP

```bash
# Reserve external IP
gcloud compute addresses create erpnext-ip \
  --region=us-central1

# Get the IP address
gcloud compute addresses describe erpnext-ip \
  --region=us-central1 \
  --format="value(address)"

# Assign to instance
gcloud compute instances add-access-config erpnext-production \
  --zone=us-central1-a \
  --access-config-name="external-nat" \
  --address=$(gcloud compute addresses describe erpnext-ip --region=us-central1 --format="value(address)")
```

### Step 4: Configure DNS

**Cloud DNS (GCP):**
```bash
# Create managed zone
gcloud dns managed-zones create yourcompany-zone \
  --dns-name=yourcompany.com \
  --description="Your Company DNS Zone"

# Add A record
gcloud dns record-sets transaction start \
  --zone=yourcompany-zone

gcloud dns record-sets transaction add YOUR_STATIC_IP \
  --name=erp.yourcompany.com \
  --ttl=300 \
  --type=A \
  --zone=yourcompany-zone

gcloud dns record-sets transaction execute \
  --zone=yourcompany-zone
```

**External DNS:**
```
Type: A
Name: erp
Value: YOUR_STATIC_IP
TTL: 300
```

### Step 5: Install Docker & Deploy

```bash
# 1. SSH into instance
gcloud compute ssh erpnext-production --zone=us-central1-a

# 2. Update system
sudo apt update && sudo apt upgrade -y

# 3. Install Docker
sudo apt install -y docker.io docker-compose
sudo systemctl enable docker
sudo systemctl start docker

# 4. Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# 5. Clone repository
git clone <your-repo-url>
cd ERPNext

# 6. Configure environment
cp .env.example .env
nano .env

# Set:
DOMAIN_NAME=erp.yourcompany.com
USE_LETSENCRYPT=true
LETSENCRYPT_EMAIL=admin@yourcompany.com
ADMIN_PASSWORD=YourSecurePassword123!
DB_ROOT_PASSWORD=YourDatabasePassword123!

# 7. Deploy
docker-compose --profile production up -d

# 8. Monitor deployment
docker-compose logs -f
```

---

## 🔐 SSL Certificate Setup

### Automatic (Let's Encrypt)

Already configured in docker-compose.yml. Just set:

```bash
# In .env file
DOMAIN_NAME=erp.yourcompany.com
USE_LETSENCRYPT=true
LETSENCRYPT_EMAIL=admin@yourcompany.com
```

See [LETSENCRYPT_GUIDE.md](LETSENCRYPT_GUIDE.md) for details.

### Manual (Custom Certificate)

If you have your own SSL certificate:

```bash
# 1. Copy certificates to server
scp fullchain.pem server:/path/to/certs/
scp privkey.pem server:/path/to/certs/

# 2. Update docker-compose.yml to mount your certificates
volumes:
  - /path/to/certs:/etc/nginx/ssl:ro

# 3. Update nginx config to use your certificates
ssl_certificate     /etc/nginx/ssl/fullchain.pem;
ssl_certificate_key /etc/nginx/ssl/privkey.pem;
```

---

## 📊 Post-Deployment Configuration

### 1. Verify All Services

```bash
# Check service status
docker-compose ps

# All services should show "Up" or "Exit 0"
```

### 2. Test Application

```bash
# Test HTTP (should redirect to HTTPS)
curl -I http://erp.yourcompany.com

# Test HTTPS
curl -I https://erp.yourcompany.com

# Should return 200 OK
```

### 3. Access Application

```
URL: https://erp.yourcompany.com
Username: Administrator
Password: (your ADMIN_PASSWORD from .env)
```

### 4. Configure Backup Strategy

```bash
# Create backup script
cat > /home/ubuntu/backup.sh <<'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups"
mkdir -p $BACKUP_DIR

# Backup database
docker exec erpnext-backend bench --site frontend backup

# Copy to S3 (AWS) or GCS (GCP)
# AWS:
# aws s3 cp /path/to/backup s3://your-bucket/erpnext-backups/

# GCP:
# gsutil cp /path/to/backup gs://your-bucket/erpnext-backups/
EOF

chmod +x /home/ubuntu/backup.sh

# Add to crontab (daily at 2 AM)
(crontab -l 2>/dev/null; echo "0 2 * * * /home/ubuntu/backup.sh") | crontab -
```

---

## 📈 Monitoring & Maintenance

### CloudWatch (AWS)

```bash
# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i amazon-cloudwatch-agent.deb

# Configure monitoring
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json
```

### Cloud Monitoring (GCP)

```bash
# Install monitoring agent
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
sudo bash add-google-cloud-ops-agent-repo.sh --also-install

# Agent will automatically collect metrics
```

### Application Monitoring

```bash
# View logs
docker-compose logs -f

# Monitor resource usage
docker stats

# Check disk space
df -h

# Monitor service health
watch -n 5 'docker-compose ps'
```

---

## 💰 Cost Optimization

### AWS Cost Estimates (us-east-1)

| Component | Specification | Monthly Cost |
|-----------|--------------|--------------|
| EC2 t3.medium | 2 vCPU, 4GB RAM | $30 |
| EC2 t3.large | 2 vCPU, 8GB RAM | $60 |
| EC2 t3.xlarge | 4 vCPU, 16GB RAM | $120 |
| EBS gp3 | 100GB SSD | $8 |
| Elastic IP | When attached | Free |
| Data Transfer | 1TB/month | $90 |
| **Total (t3.large)** | | **$158/month** |

### GCP Cost Estimates (us-central1)

| Component | Specification | Monthly Cost |
|-----------|--------------|--------------|
| e2-standard-2 | 2 vCPU, 8GB RAM | $49 |
| e2-standard-4 | 4 vCPU, 16GB RAM | $98 |
| SSD Disk | 100GB | $17 |
| Static IP | When attached | Free |
| Network Egress | 1TB/month | $120 |
| **Total (e2-standard-4)** | | **$235/month** |

### Cost Optimization Tips

1. **Use Reserved Instances** (AWS) or **Committed Use Discounts** (GCP)
   - Save up to 72% on compute costs
   - 1-year or 3-year commitments

2. **Right-size Your Instance**
   - Start with smaller instance
   - Monitor usage and scale up if needed
   - Use auto-scaling for variable loads

3. **Optimize Storage**
   - Use gp3 (AWS) instead of gp2
   - Regular cleanup of old backups
   - Compress log files

4. **Network Optimization**
   - Use CDN for static assets
   - Enable compression
   - Optimize images and files

5. **Use Spot Instances** (Non-production)
   - Save up to 90% on compute
   - Good for development/testing

---

## ✅ Production Checklist

### Pre-Deployment
- [ ] Domain name registered
- [ ] DNS configured and propagated
- [ ] SSL certificate strategy decided
- [ ] Backup strategy planned
- [ ] Security groups/firewall configured
- [ ] Instance size determined

### Deployment
- [ ] Instance launched
- [ ] Static/Elastic IP assigned
- [ ] Docker installed
- [ ] Application deployed
- [ ] Let's Encrypt certificate obtained
- [ ] Application accessible via HTTPS

### Post-Deployment
- [ ] All services healthy
- [ ] SSL certificate valid
- [ ] Automated backups configured
- [ ] Monitoring set up
- [ ] Log rotation configured
- [ ] Team access configured
- [ ] Documentation updated

### Security
- [ ] SSH restricted to admin IPs
- [ ] Only ports 80/443 exposed
- [ ] Strong passwords set
- [ ] Database not publicly accessible
- [ ] Regular security updates scheduled
- [ ] Firewall rules reviewed

---

## 🆘 Troubleshooting

### Can't Access Application

```bash
# 1. Check security group/firewall
# Ensure ports 80 and 443 are open to 0.0.0.0/0

# 2. Check services are running
docker-compose ps

# 3. Check logs
docker-compose logs frontend

# 4. Test connectivity
curl http://YOUR_IP
```

### SSL Certificate Issues

See [LETSENCRYPT_GUIDE.md](LETSENCRYPT_GUIDE.md#-troubleshooting)

### Performance Issues

```bash
# Check resource usage
docker stats

# Check disk space
df -h

# Check memory
free -h

# Consider upgrading instance type
```

---

## 📚 Additional Resources

- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)
- [GCP Compute Engine Docs](https://cloud.google.com/compute/docs)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [ERPNext Documentation](https://docs.erpnext.com/)

---

**Your ERPNext instance is now production-ready on the cloud! 🚀**

For additional help, see:
- [DOCKER_COMPOSE_GUIDE.md](DOCKER_COMPOSE_GUIDE.md) - Complete Docker Compose guide
- [LETSENCRYPT_GUIDE.md](LETSENCRYPT_GUIDE.md) - SSL certificate management
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues and solutions