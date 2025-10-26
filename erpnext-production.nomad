job "erpnext-full" {
  datacenters = ["dc1"]
  type        = "service"

  # Deploy to docker-server node
  constraint {
    attribute = "${node.unique.name}"
    value     = "docker-server"
  }

  # Database group
  group "database" {
    count = 1

    network {
      mode = "bridge"
    }

    # Docker volume - automatically created
    volume "mariadb-data" {
      type   = "docker"
      source = "erpnext_mariadb_data"
    }

    task "mariadb" {
      driver = "docker"

      config {
        image = "mariadb:10.6"
        network_mode = "lan_routed_net"
        
        args = [
          "--character-set-server=utf8mb4",
          "--collation-server=utf8mb4_unicode_ci",
          "--skip-character-set-client-handshake",
          "--skip-innodb-read-only-compressed"
        ]
      }

      volume_mount {
        volume      = "mariadb-data"
        destination = "/var/lib/mysql"
      }

      env {
        MYSQL_ROOT_PASSWORD   = "CHANGE_THIS_SECURE_PASSWORD"
        MARIADB_ROOT_PASSWORD = "CHANGE_THIS_SECURE_PASSWORD"
      }

      resources {
        cpu    = 500
        memory = 1024
      }

      service {
        name = "erpnext-mariadb"
        
        check {
          type     = "script"
          name     = "mariadb_health"
          command  = "/usr/bin/mysqladmin"
          args     = ["ping", "-h", "localhost", "--password=CHANGE_THIS_SECURE_PASSWORD"]
          interval = "10s"
          timeout  = "5s"
        }
      }
    }
  }

  # Redis group (3 instances)
  group "redis" {
    count = 1

    network {
      mode = "bridge"
    }

    volume "redis-cache" {
      type   = "docker"
      source = "erpnext_redis_cache"
    }

    volume "redis-queue" {
      type   = "docker"
      source = "erpnext_redis_queue"
    }

    volume "redis-socketio" {
      type   = "docker"
      source = "erpnext_redis_socketio"
    }

    task "redis-cache" {
      driver = "docker"

      config {
        image        = "redis:6.2-alpine"
        network_mode = "lan_routed_net"
      }

      volume_mount {
        volume      = "redis-cache"
        destination = "/data"
      }

      resources {
        cpu    = 200
        memory = 256
      }

      service {
        name = "erpnext-redis-cache"
        check {
          type     = "tcp"
          port     = 6379
          interval = "10s"
          timeout  = "2s"
        }
      }
    }

    task "redis-queue" {
      driver = "docker"

      config {
        image        = "redis:6.2-alpine"
        network_mode = "lan_routed_net"
      }

      volume_mount {
        volume      = "redis-queue"
        destination = "/data"
      }

      resources {
        cpu    = 200
        memory = 256
      }

      service {
        name = "erpnext-redis-queue"
        check {
          type     = "tcp"
          port     = 6379
          interval = "10s"
          timeout  = "2s"
        }
      }
    }

    task "redis-socketio" {
      driver = "docker"

      config {
        image        = "redis:6.2-alpine"
        network_mode = "lan_routed_net"
      }

      volume_mount {
        volume      = "redis-socketio"
        destination = "/data"
      }

      resources {
        cpu    = 200
        memory = 256
      }

      service {
        name = "erpnext-redis-socketio"
        check {
          type     = "tcp"
          port     = 6379
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }

  # Application group (Backend, WebSocket, Frontend with HTTPS)
  group "application" {
    count = 1

    network {
      mode = "bridge"
    }

    volume "sites" {
      type   = "docker"
      source = "erpnext_sites"
    }

    volume "logs" {
      type   = "docker"
      source = "erpnext_logs"
    }

    volume "ssl" {
      type   = "docker"
      source = "erpnext_ssl_certs"
    }

    # Configurator - runs once
    task "configurator" {
      driver = "docker"
      
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      config {
        # CHANGE THIS: Use your custom image
        image        = "your-registry/erpnext-full:latest"
        network_mode = "lan_routed_net"
        command      = "configure.py"
      }

      volume_mount {
        volume      = "sites"
        destination = "/home/frappe/frappe-bench/sites"
      }

      template {
        data = <<EOF
DB_HOST={{ range service "erpnext-mariadb" }}{{ .Address }}{{ end }}
DB_PORT=3306
REDIS_CACHE={{ range service "erpnext-redis-cache" }}{{ .Address }}{{ end }}:6379
REDIS_QUEUE={{ range service "erpnext-redis-queue" }}{{ .Address }}{{ end }}:6379
REDIS_SOCKETIO={{ range service "erpnext-redis-socketio" }}{{ .Address }}{{ end }}:6379
SOCKETIO_PORT=9000
EOF
        destination = "local/env"
        env         = true
      }

      resources {
        cpu    = 200
        memory = 512
      }
    }

    # Create site and install all apps - runs once
    task "create-site" {
      driver = "docker"
      
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      config {
        # CHANGE THIS: Use your custom image
        image        = "your-registry/erpnext-full:latest"
        network_mode = "lan_routed_net"
        command      = "bash"
        args = ["-c", <<EOF
sleep 30

# Create site
bench new-site frontend \
  --no-mariadb-socket \
  --admin-password=CHANGE_ADMIN_PASSWORD \
  --db-root-password=CHANGE_THIS_SECURE_PASSWORD \
  --install-app erpnext \
  --set-default

# Install all additional apps
bench --site frontend install-app hrms
bench --site frontend install-app crm  
bench --site frontend install-app helpdesk
bench --site frontend install-app insights
bench --site frontend install-app gameplan
bench --site frontend install-app lms
bench --site frontend install-app healthcare
bench --site frontend install-app lending

echo "Site created with all apps installed"
EOF
        ]
      }

      volume_mount {
        volume      = "sites"
        destination = "/home/frappe/frappe-bench/sites"
      }

      template {
        data = <<EOF
DB_HOST={{ range service "erpnext-mariadb" }}{{ .Address }}{{ end }}
DB_PORT=3306
REDIS_CACHE={{ range service "erpnext-redis-cache" }}{{ .Address }}{{ end }}:6379
REDIS_QUEUE={{ range service "erpnext-redis-queue" }}{{ .Address }}{{ end }}:6379
REDIS_SOCKETIO={{ range service "erpnext-redis-socketio" }}{{ .Address }}{{ end }}:6379
SOCKETIO_PORT=9000
EOF
        destination = "local/env"
        env         = true
      }

      resources {
        cpu    = 1000
        memory = 2048
      }
    }

    # Backend - runs ALL apps
    task "backend" {
      driver = "docker"

      config {
        # CHANGE THIS: Use your custom image
        image        = "your-registry/erpnext-full:latest"
        network_mode = "lan_routed_net"
      }

      volume_mount {
        volume      = "sites"
        destination = "/home/frappe/frappe-bench/sites"
      }

      volume_mount {
        volume      = "logs"
        destination = "/home/frappe/frappe-bench/logs"
      }

      template {
        data = <<EOF
DB_HOST={{ range service "erpnext-mariadb" }}{{ .Address }}{{ end }}
DB_PORT=3306
REDIS_CACHE={{ range service "erpnext-redis-cache" }}{{ .Address }}{{ end }}:6379
REDIS_QUEUE={{ range service "erpnext-redis-queue" }}{{ .Address }}{{ end }}:6379
REDIS_SOCKETIO={{ range service "erpnext-redis-socketio" }}{{ .Address }}{{ end }}:6379
SOCKETIO_PORT=9000
MYSQL_ROOT_PASSWORD=CHANGE_THIS_SECURE_PASSWORD
MARIADB_ROOT_PASSWORD=CHANGE_THIS_SECURE_PASSWORD
EOF
        destination = "local/env"
        env         = true
      }

      resources {
        cpu    = 2000
        memory = 4096
      }

      service {
        name = "erpnext-backend"
        check {
          type     = "tcp"
          port     = 8000
          interval = "10s"
          timeout  = "2s"
        }
      }
    }

    # WebSocket - real-time features
    task "websocket" {
      driver = "docker"

      config {
        # CHANGE THIS: Use your custom image
        image        = "your-registry/erpnext-full:latest"
        network_mode = "lan_routed_net"
        command      = "node"
        args         = ["/home/frappe/frappe-bench/apps/frappe/socketio.js"]
      }

      volume_mount {
        volume      = "sites"
        destination = "/home/frappe/frappe-bench/sites"
      }

      template {
        data = <<EOF
REDIS_SOCKETIO={{ range service "erpnext-redis-socketio" }}{{ .Address }}{{ end }}:6379
EOF
        destination = "local/env"
        env         = true
      }

      resources {
        cpu    = 200
        memory = 512
      }

      service {
        name = "erpnext-websocket"
        check {
          type     = "tcp"
          port     = 9000
          interval = "10s"
          timeout  = "2s"
        }
      }
    }

    # Frontend - HTTPS on port 443
    task "frontend" {
      driver = "docker"

      config {
        # CHANGE THIS: Use your custom image (has nginx + bench files)
        image        = "your-registry/erpnext-full:latest"
        network_mode = "lan_routed_net"
        command      = "bash"
        args = ["-c", <<EOF
# Setup SSL certificate
mkdir -p /etc/nginx/ssl
if [ ! -f /etc/nginx/ssl/cert.pem ]; then
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/key.pem \
    -out /etc/nginx/ssl/cert.pem \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=erp.yourdomain.com"
fi

# Get backend and websocket addresses
BACKEND_ADDR="{{ range service "erpnext-backend" }}{{ .Address }}{{ end }}"
WEBSOCKET_ADDR="{{ range service "erpnext-websocket" }}{{ .Address }}{{ end }}"

# Create nginx configuration
cat > /etc/nginx/conf.d/erpnext.conf <<NGINX
upstream backend {
    server ${BACKEND_ADDR}:8000;
}

upstream socketio {
    server ${WEBSOCKET_ADDR}:9000;
}

# HTTP -> HTTPS redirect
server {
    listen 80;
    server_name _;
    return 301 https://\$host\$request_uri;
}

# HTTPS Server
server {
    listen 443 ssl http2;
    server_name _;

    ssl_certificate     /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;

    client_max_body_size 50m;
    root /home/frappe/frappe-bench/sites;

    location /assets {
        try_files \$uri =404;
    }

    location ~ ^/protected/(.*) {
        internal;
        try_files /frontend/\$1 =404;
    }

    location /socket.io {
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header X-Frappe-Site-Name frontend;
        proxy_set_header Origin \$scheme://\$http_host;
        proxy_set_header Host \$host;
        proxy_pass http://socketio;
    }

    location / {
        rewrite ^(.+)/$ \$1 permanent;
        rewrite ^(.+)/index\\.html$ \$1 permanent;
        rewrite ^(.+)\\.html$ \$1 permanent;

        location ~ ^/files/.*.(htm|html|svg|xml) {
            add_header Content-disposition "attachment";
            try_files /frontend/\$uri @backend;
        }

        try_files /frontend/\$uri @backend;
    }

    location @backend {
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Frappe-Site-Name frontend;
        proxy_set_header Host \$host;
        proxy_set_header X-Use-X-Accel-Redirect True;
        proxy_read_timeout 120;
        proxy_redirect off;
        proxy_pass http://backend;
    }
}
NGINX

# Start nginx
nginx -g 'daemon off;'
EOF
        ]
      }

      volume_mount {
        volume      = "sites"
        destination = "/home/frappe/frappe-bench/sites"
      }

      volume_mount {
        volume      = "ssl"
        destination = "/etc/nginx/ssl"
      }

      resources {
        cpu    = 500
        memory = 1024
      }

      service {
        name = "erpnext-frontend"
        
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.erpnext.rule=Host(`erp.yourdomain.com`)",
          "traefik.http.routers.erpnext.tls=true",
        ]

        check {
          type     = "tcp"
          port     = 443
          interval = "30s"
          timeout  = "5s"
        }
      }
    }
  }

  # Workers group (Scheduler + Queue workers)
  group "workers" {
    count = 1

    network {
      mode = "bridge"
    }

    volume "sites" {
      type   = "docker"
      source = "erpnext_sites"
    }

    volume "logs" {
      type   = "docker"
      source = "erpnext_logs"
    }

    # Scheduler - runs cron jobs for all apps
    task "scheduler" {
      driver = "docker"

      config {
        # CHANGE THIS: Use your custom image
        image        = "your-registry/erpnext-full:latest"
        network_mode = "lan_routed_net"
        command      = "bench"
        args         = ["schedule"]
      }

      volume_mount {
        volume      = "sites"
        destination = "/home/frappe/frappe-bench/sites"
      }

      volume_mount {
        volume      = "logs"
        destination = "/home/frappe/frappe-bench/logs"
      }

      template {
        data = <<EOF
REDIS_CACHE={{ range service "erpnext-redis-cache" }}{{ .Address }}{{ end }}:6379
REDIS_QUEUE={{ range service "erpnext-redis-queue" }}{{ .Address }}{{ end }}:6379
EOF
        destination = "local/env"
        env         = true
      }

      resources {
        cpu    = 200
        memory = 512
      }
    }

    # Short queue worker - quick jobs
    task "queue-short" {
      driver = "docker"

      config {
        # CHANGE THIS: Use your custom image
        image        = "your-registry/erpnext-full:latest"
        network_mode = "lan_routed_net"
        command      = "bench"
        args         = ["worker", "--queue", "short,default"]
      }

      volume_mount {
        volume      = "sites"
        destination = "/home/frappe/frappe-bench/sites"
      }

      volume_mount {
        volume      = "logs"
        destination = "/home/frappe/frappe-bench/logs"
      }

      template {
        data = <<EOF
REDIS_CACHE={{ range service "erpnext-redis-cache" }}{{ .Address }}{{ end }}:6379
REDIS_QUEUE={{ range service "erpnext-redis-queue" }}{{ .Address }}{{ end }}:6379
EOF
        destination = "local/env"
        env         = true
      }

      resources {
        cpu    = 1000
        memory = 2048
      }
    }

    # Long queue worker - long-running jobs
    task "queue-long" {
      driver = "docker"

      config {
        # CHANGE THIS: Use your custom image
        image        = "your-registry/erpnext-full:latest"
        network_mode = "lan_routed_net"
        command      = "bench"
        args         = ["worker", "--queue", "long,default,short"]
      }

      volume_mount {
        volume      = "sites"
        destination = "/home/frappe/frappe-bench/sites"
      }

      volume_mount {
        volume      = "logs"
        destination = "/home/frappe/frappe-bench/logs"
      }

      template {
        data = <<EOF
REDIS_CACHE={{ range service "erpnext-redis-cache" }}{{ .Address }}{{ end }}:6379
REDIS_QUEUE={{ range service "erpnext-redis-queue" }}{{ .Address }}{{ end }}:6379
EOF
        destination = "local/env"
        env         = true
      }

      resources {
        cpu    = 1000
        memory = 2048
      }
    }
  }
}
