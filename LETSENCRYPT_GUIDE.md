# Let's Encrypt SSL Certificate Setup Guide

This guide explains how to set up automatic SSL certificates using Let's Encrypt with your ERPNext Docker Compose deployment.

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Certificate Renewal](#certificate-renewal)
- [Troubleshooting](#troubleshooting)

## 🎯 Overview

This setup includes:
- **Automatic SSL certificate acquisition** from Let's Encrypt
- **Automatic certificate renewal** (every 12 hours check)
- **Zero-downtime certificate updates**
- **Fallback to self-signed certificates** if Let's Encrypt is disabled

### How It Works

1. **Certbot service** requests certificates from Let's Encrypt
2. **ACME challenge** validates domain ownership via HTTP
3. **Nginx** serves ACME challenge files and uses obtained certificates
4. **Auto-renewal** happens every 12 hours in background

## ✅ Prerequisites

### 1. Domain Name Requirements

- ✅ You must own a domain name
- ✅ Domain must point to your server's public IP
- ✅ DNS must be properly configured (A record)

**Check DNS configuration:**
```bash
# Replace with your domain
dig +short erp.yourcompany.com

# Should return your server's public IP
```

### 2. Firewall/Security Groups

Ensure these ports are open to the internet:
- **Port 80** (HTTP) - Required for ACME challenge
- **Port 443** (HTTPS) - For secure access

**AWS Security Group Example:**
```bash
# HTTP (required for ACME challenge)
Port 80: 0.0.0.0/0

# HTTPS (secure access)
Port 443: 0.0.0.0/0
```

### 3. Email Address

You need a valid email address for Let's Encrypt notifications (certificate expiry warnings).

## ⚙️ Configuration

### Step 1: Edit `.env` File

```bash
cp .env.example .env
nano .env
```

### Step 2: Configure Let's Encrypt Settings

```bash
# =============================================================================
# Site Configuration
# =============================================================================
SITE_NAME=frontend
DOMAIN_NAME=erp.yourcompany.com  # YOUR ACTUAL DOMAIN

# =============================================================================
# Let's Encrypt SSL Configuration  
# =============================================================================
USE_LETSENCRYPT=true                    # Enable Let's Encrypt
LETSENCRYPT_EMAIL=admin@yourcompany.com  # Your email for notifications
ADDITIONAL_DOMAINS=                      # Leave empty unless you have subdomains

# =============================================================================
# Security (Change these!)
# =============================================================================
ADMIN_PASSWORD=YourSecurePassword123!
DB_ROOT_PASSWORD=YourDatabasePassword123!
```

### Example Configurations

#### Single Domain (Most Common)
```bash
DOMAIN_NAME=erp.mycompany.com
USE_LETSENCRYPT=true
LETSENCRYPT_EMAIL=admin@mycompany.com
ADDITIONAL_DOMAINS=
```

#### Multiple Domains (Advanced)
```bash
DOMAIN_NAME=erp.mycompany.com
USE_LETSENCRYPT=true
LETSENCRYPT_EMAIL=admin@mycompany.com
ADDITIONAL_DOMAINS=-d www.erp.mycompany.com -d erp2.mycompany.com
```

#### Development (Self-Signed)
```bash
DOMAIN_NAME=localhost
USE_LETSENCRYPT=false
LETSENCRYPT_EMAIL=  # Not needed
```

## 🚀 Deployment

### Option 1: Production Deployment with Let's Encrypt

```bash
# 1. Configure .env with your domain
nano .env

# 2. Make sure DNS is pointing to your server
dig +short erp.yourcompany.com

# 3. Deploy with production profile
docker-compose --profile production up -d

# 4. Wait for certificate acquisition (2-5 minutes)
docker-compose logs -f certbot-init

# 5. Access your site
https://erp.yourcompany.com
```

### Option 2: Development Deployment (Self-Signed)

```bash
# 1. Configure .env with USE_LETSENCRYPT=false
nano .env

# 2. Deploy without production profile
docker-compose up -d

# 3. Access your site (will show browser warning)
https://localhost
```

## 🔄 Certificate Renewal

### Automatic Renewal

Certificates are automatically renewed:
- **Check interval**: Every 12 hours
- **Renewal trigger**: 30 days before expiry
- **Zero downtime**: Nginx reloads gracefully

**Monitor renewal:**
```bash
# Check certbot renewal service logs
docker-compose logs -f certbot

# Check certificate expiry
docker exec erpnext-certbot certbot certificates
```

### Manual Renewal

If needed, you can manually trigger renewal:

```bash
# Force certificate renewal
docker exec erpnext-certbot certbot renew --force-renewal

# Reload nginx to use new certificate
docker-compose restart frontend
```

## 📊 Certificate Management

### View Certificate Details

```bash
# List all certificates
docker exec erpnext-certbot certbot certificates

# Expected output:
# Found the following certs:
#   Certificate Name: erp.yourcompany.com
#     Domains: erp.yourcompany.com
#     Expiry Date: 2024-XX-XX
#     Certificate Path: /etc/letsencrypt/live/erp.yourcompany.com/fullchain.pem
#     Private Key Path: /etc/letsencrypt/live/erp.yourcompany.com/privkey.pem
```

### Check Certificate Expiry

```bash
# Check when certificate expires
docker exec erpnext-certbot certbot certificates | grep "Expiry Date"
```

### Revoke Certificate

If you need to revoke a certificate:

```bash
docker exec erpnext-certbot certbot revoke \
  --cert-path /etc/letsencrypt/live/erp.yourcompany.com/cert.pem
```

## 🐛 Troubleshooting

### Issue 1: Certificate Acquisition Fails

**Symptoms:**
```
Failed to obtain certificate
ACME challenge failed
Connection refused
```

**Solutions:**

1. **Check DNS is pointing to your server:**
   ```bash
   dig +short erp.yourcompany.com
   # Should return your server's public IP
   ```

2. **Verify port 80 is accessible:**
   ```bash
   # From another machine
   curl http://erp.yourcompany.com/.well-known/acme-challenge/test
   ```

3. **Check firewall rules:**
   ```bash
   # Port 80 must be open to 0.0.0.0/0
   # Check security groups (AWS) or firewall rules (GCP)
   ```

4. **View certbot logs:**
   ```bash
   docker-compose logs certbot-init
   ```

### Issue 2: Domain Not Resolving

**Check DNS propagation:**
```bash
# Check from multiple locations
dig +short erp.yourcompany.com @8.8.8.8
dig +short erp.yourcompany.com @1.1.1.1

# Wait 5-10 minutes for DNS propagation
```

### Issue 3: Rate Limiting

Let's Encrypt has rate limits:
- **5 certificates per domain per week**
- **50 certificates per registered domain per week**

**Solution:**
- Use Let's Encrypt staging server for testing:
  ```bash
  docker exec erpnext-certbot certbot certonly --staging \
    --webroot -w /var/www/certbot \
    -d erp.yourcompany.com
  ```

### Issue 4: Certificate Not Being Used

**Check which certificate is active:**
```bash
# Check nginx configuration
docker exec erpnext-frontend cat /etc/nginx/conf.d/erpnext.conf | grep ssl_certificate

# Verify certificate files exist
docker exec erpnext-frontend ls -la /etc/letsencrypt/live/erp.yourcompany.com/
```

**Restart frontend to reload certificates:**
```bash
docker-compose restart frontend
```

### Issue 5: ACME Challenge Not Accessible

**Test ACME challenge endpoint:**
```bash
# Should return 404 (not 403 or connection refused)
curl http://erp.yourcompany.com/.well-known/acme-challenge/test
```

**Check nginx configuration:**
```bash
docker exec erpnext-frontend cat /etc/nginx/conf.d/erpnext.conf | grep -A 3 "\.well-known"
```

## 🔧 Advanced Configuration

### Custom Certbot Options

Edit `docker-compose.yml` certbot-init service to add custom options:

```yaml
certbot-init:
  image: certbot/certbot:latest
  command: >
    sh -c "
    certbot certonly --webroot \
      -w /var/www/certbot \
      --email ${LETSENCRYPT_EMAIL} \
      --agree-tos \
      --no-eff-email \
      --rsa-key-size 4096 \          # Custom: Larger key size
      --must-staple \                 # Custom: OCSP stapling
      -d ${DOMAIN_NAME};
    "
```

### Wildcard Certificates

For wildcard certificates (*.example.com), you need DNS validation:

```yaml
certbot-init:
  command: >
    sh -c "
    certbot certonly \
      --dns-cloudflare \
      --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini \
      -d example.com \
      -d *.example.com;
    "
```

## 📝 Migration from Self-Signed to Let's Encrypt

If you're already running with self-signed certificates:

```bash
# 1. Stop the deployment
docker-compose down

# 2. Update .env file
nano .env
# Set USE_LETSENCRYPT=true
# Set DOMAIN_NAME and LETSENCRYPT_EMAIL

# 3. Ensure DNS is configured
dig +short erp.yourcompany.com

# 4. Start with production profile
docker-compose --profile production up -d

# 5. Monitor certificate acquisition
docker-compose logs -f certbot-init

# 6. Access via HTTPS
https://erp.yourcompany.com
```

## 🔒 Security Best Practices

1. **Use strong SSL configuration** (already configured in nginx)
2. **Enable HSTS** (HTTP Strict Transport Security)
3. **Monitor certificate expiry** (set up alerts)
4. **Keep email address current** for renewal notifications
5. **Test SSL configuration**: https://www.ssllabs.com/ssltest/

### Enable HSTS (Recommended for Production)

Add to nginx configuration in `docker-compose.yml`:

```nginx
# In the HTTPS server block, add:
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
```

## 📋 Checklist for Production

Before going live with Let's Encrypt:

- [ ] Domain name purchased and configured
- [ ] DNS A record points to server IP
- [ ] Port 80 and 443 open in firewall/security group
- [ ] `.env` file configured with correct domain and email
- [ ] `USE_LETSENCRYPT=true` in `.env`
- [ ] DNS propagation verified (`dig` command)
- [ ] Deployment tested (`docker-compose --profile production up -d`)
- [ ] Certificate obtained successfully (check logs)
- [ ] Site accessible via HTTPS
- [ ] Browser shows valid certificate (green lock icon)
- [ ] Auto-renewal service running (`docker-compose ps`)

## 🆘 Getting Help

If you encounter issues:

1. Check Let's Encrypt status: https://letsencrypt.status.io/
2. Review logs: `docker-compose logs certbot-init`
3. Test ACME challenge: `curl http://yourdomain/.well-known/acme-challenge/test`
4. Verify DNS: `dig +short yourdomain.com`
5. Check Let's Encrypt community: https://community.letsencrypt.org/

## 📚 Additional Resources

- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Certbot Documentation](https://eff-certbot.readthedocs.io/)
- [SSL Labs Server Test](https://www.ssllabs.com/ssltest/)
- [Let's Encrypt Rate Limits](https://letsencrypt.org/docs/rate-limits/)

---

**Your SSL certificates will be automatically managed and renewed! 🎉**