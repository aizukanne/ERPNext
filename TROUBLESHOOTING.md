# ERPNext Nomad Troubleshooting Guide

## Common Issues and Solutions

### 1. Job Fails to Start

#### Symptom
```
nomad job run erpnext.nomad
Error: constraint not satisfied
```

#### Solution
Check your node name and update the constraint in the job file:

```bash
# Get your node name
nomad node status -self | grep Name

# Update erpnext.nomad:
constraint {
  attribute = "${node.unique.name}"
  value     = "your-actual-node-name"
}
```

---

### 2. Host Volumes Not Found

#### Symptom
```
Error: host volume "erpnext-sites" is not available
```

#### Solution
1. Ensure volumes are configured in Nomad client:
```bash
sudo nano /etc/nomad.d/client.hcl
```

2. Add host volume configuration (see README.md)

3. Restart Nomad:
```bash
sudo systemctl restart nomad
```

4. Verify volumes:
```bash
nomad node status -self -verbose | grep -A 5 "Host Volumes"
```

---

### 3. Site Creation Fails

#### Symptom
```
nomad alloc logs <alloc-id> create-site
Error: Could not connect to database
```

#### Solution A: Database not ready yet
Wait 30 seconds and check again. The database needs time to initialize.

```bash
# Check MariaDB health
nomad alloc status <db-alloc-id>
nomad alloc logs <db-alloc-id> mariadb
```

#### Solution B: Wrong password
Ensure all password references match in the job file:
- MariaDB environment variables
- create-site command
- Backend environment variables

---

### 4. Site Already Exists Error

#### Symptom
```
Error: Site frontend already exists
```

#### Solution
This is **normal** on job restart. The create-site task only needs to run once.

To verify the site is working:
```bash
nomad alloc exec <app-alloc-id> backend bash
cd /home/frappe/frappe-bench
bench --site frontend doctor
```

---

### 5. Cannot Access ERPNext on Port 8080

#### Symptom
Browser shows "Connection refused" or timeout when accessing http://<ip>:8080

#### Solution A: Check if frontend is running
```bash
nomad job status erpnext
nomad alloc status <app-alloc-id>
nomad alloc logs <app-alloc-id> frontend
```

#### Solution B: Firewall blocking port
```bash
# Ubuntu/Debian
sudo ufw allow 8080
sudo ufw status

# CentOS/RHEL
sudo firewall-cmd --add-port=8080/tcp --permanent
sudo firewall-cmd --reload
```

#### Solution C: Check port binding
```bash
# On the Nomad client node
sudo netstat -tlnp | grep 8080
# or
sudo ss -tlnp | grep 8080
```

---

### 6. WebSocket/Real-time Features Not Working

#### Symptom
Real-time updates not working, console errors about WebSocket

#### Solution
1. Check websocket task:
```bash
nomad alloc logs <app-alloc-id> websocket
```

2. Verify Redis socketio is running:
```bash
nomad alloc status <redis-alloc-id>
```

3. Check environment variables:
```bash
nomad alloc exec <app-alloc-id> frontend env | grep SOCKETIO
```

---

### 7. Slow Performance

#### Symptom
ERPNext is slow to load or respond

#### Solution A: Increase resources
Edit erpnext.nomad and increase CPU/memory:

```hcl
resources {
  cpu    = 2000  # Increase from 1000
  memory = 4096  # Increase from 2048
}
```

#### Solution B: Scale workers
```hcl
group "workers" {
  count = 3  # Increase from 1
}
```

#### Solution C: Check resource usage
```bash
nomad alloc status <alloc-id>
docker stats $(docker ps -q --filter "name=erpnext")
```

#### Solution D: Clear cache
```bash
nomad alloc exec <app-alloc-id> backend bash
cd /home/frappe/frappe-bench
bench --site frontend clear-cache
```

---

### 8. Database Connection Errors

#### Symptom
```
Could not connect to MariaDB
Connection refused to DB_HOST
```

#### Solution
1. Check if MariaDB is running:
```bash
nomad alloc status <db-alloc-id>
```

2. Test database connection:
```bash
nomad alloc exec <app-alloc-id> backend bash
mysql -h $(echo $DB_HOST) -u root -p
# Enter password when prompted
```

3. Verify service discovery:
```bash
nomad service info erpnext-mariadb
```

---

### 9. Redis Connection Errors

#### Symptom
```
Could not connect to Redis
Connection timeout
```

#### Solution
1. Check Redis tasks:
```bash
nomad alloc status <redis-alloc-id>
nomad alloc logs <redis-alloc-id> redis-cache
```

2. Test Redis connectivity:
```bash
nomad alloc exec <app-alloc-id> backend bash
redis-cli -h $(echo $REDIS_CACHE | cut -d: -f1) -p $(echo $REDIS_CACHE | cut -d: -f2) ping
# Should return: PONG
```

---

### 10. Worker Tasks Not Processing Jobs

#### Symptom
Background jobs stuck in queue, not being processed

#### Solution
1. Check worker logs:
```bash
nomad alloc logs <worker-alloc-id> queue-short
nomad alloc logs <worker-alloc-id> queue-long
nomad alloc logs <worker-alloc-id> scheduler
```

2. Check Redis queue:
```bash
nomad alloc exec <app-alloc-id> backend bash
cd /home/frappe/frappe-bench
bench --site frontend redis-queue-status
```

3. Restart workers:
```bash
nomad alloc restart <worker-alloc-id>
```

---

### 11. "Out of Disk Space" Errors

#### Symptom
```
Error: No space left on device
```

#### Solution
1. Check disk usage:
```bash
df -h /opt/nomad-volumes/erpnext/
```

2. Clean up logs:
```bash
sudo find /opt/nomad-volumes/erpnext/logs/ -type f -name "*.log" -mtime +7 -delete
```

3. Clean Docker:
```bash
docker system prune -a
docker volume prune
```

---

### 12. Cannot Install Custom Apps

#### Symptom
Trying to run `bench get-app` but it doesn't work

#### Solution
**Important**: You cannot install apps in running containers with the official frappe/erpnext image.

To install custom apps, you need to:
1. Build a custom Docker image with the app included
2. Update the job file to use your custom image

See: https://github.com/frappe/frappe_docker/blob/main/docs/custom-apps.md

---

### 13. Upgrade Failures

#### Symptom
After upgrading, site doesn't work or shows errors

#### Solution
1. Check migration logs:
```bash
nomad alloc logs <app-alloc-id> backend | grep -i migrate
```

2. Manually run migrations:
```bash
nomad alloc exec <app-alloc-id> backend bash
cd /home/frappe/frappe-bench
bench --site frontend migrate
```

3. Rollback if needed:
```bash
# Edit erpnext.nomad back to previous version
image = "frappe/erpnext:v15.75.1"

nomad job run erpnext.nomad
```

---

### 14. Permission Denied Errors

#### Symptom
```
Permission denied: '/home/frappe/frappe-bench/sites/...'
```

#### Solution
Fix volume ownership on the host:
```bash
sudo chown -R 1000:1000 /opt/nomad-volumes/erpnext/
sudo chmod -R 755 /opt/nomad-volumes/erpnext/
```

---

### 15. Nomad Agent Not Starting

#### Symptom
```
sudo systemctl status nomad
Active: failed
```

#### Solution
1. Check logs:
```bash
sudo journalctl -u nomad -n 50
```

2. Validate config:
```bash
nomad agent -config=/etc/nomad.d/ -dev
```

3. Common issues:
   - Syntax errors in client.hcl
   - Invalid paths in host volume config
   - Port conflicts

---

## Debugging Techniques

### View All Logs
```bash
# Get all allocation IDs
ALLOC_IDS=$(nomad job status erpnext -json | jq -r '.Allocations[].ID')

# View logs for all allocations
for alloc in $ALLOC_IDS; do
  echo "=== Allocation: $alloc ==="
  nomad alloc status $alloc
  echo
done
```

### Check Service Connectivity
```bash
# From backend container
nomad alloc exec <app-alloc-id> backend bash

# Test MariaDB
mysql -h $DB_HOST -P $DB_PORT -u root -p

# Test Redis
redis-cli -h $(echo $REDIS_CACHE | cut -d: -f1) -p $(echo $REDIS_CACHE | cut -d: -f2) ping

# Test HTTP endpoints
curl http://localhost:8000
```

### Monitor Resource Usage
```bash
# Watch allocation status
watch -n 2 "nomad alloc status <alloc-id>"

# Docker stats
watch -n 2 "docker stats --no-stream $(docker ps -q --filter 'name=erpnext')"
```

### Check Network Connectivity
```bash
# On Nomad client node
docker network ls
docker network inspect <network-id>

# Inside container
nomad alloc exec <alloc-id> backend bash
apt-get update && apt-get install -y iputils-ping dnsutils
ping -c 3 <service-name>.service.consul
nslookup <service-name>.service.consul
```

---

## Getting More Help

If you're still stuck:

1. **Collect diagnostic information:**
```bash
nomad job status erpnext > erpnext-status.txt
nomad alloc status <alloc-id> > alloc-status.txt
nomad alloc logs <alloc-id> <task-name> > task-logs.txt
```

2. **Check ERPNext Forum:**
   - https://discuss.erpnext.com/

3. **Check Nomad Discuss:**
   - https://discuss.hashicorp.com/c/nomad/

4. **Review Documentation:**
   - ERPNext: https://docs.erpnext.com/
   - Frappe Docker: https://github.com/frappe/frappe_docker
   - Nomad: https://www.nomadproject.io/docs

5. **Enable Debug Logging:**
   In erpnext.nomad, add to environment variables:
   ```hcl
   env {
     FRAPPE_LOGGING_LEVEL = "DEBUG"
   }
   ```
