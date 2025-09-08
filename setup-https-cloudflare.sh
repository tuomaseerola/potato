#!/bin/bash

# Setup HTTPS with Cloudflare SSL
# Run this on your DigitalOcean droplet
# REQUIRES: Domain managed by Cloudflare

set -e

echo "🔒 Setting up HTTPS with Cloudflare SSL..."
echo "========================================="

if [ $# -eq 0 ]; then
    echo "❌ Domain name required!"
    echo ""
    echo "Usage: $0 your-domain.com"
    echo ""
    echo "Prerequisites:"
    echo "1. Domain must be managed by Cloudflare"
    echo "2. Cloudflare SSL/TLS mode set to 'Full' or 'Full (strict)'"
    echo "3. Domain A record pointing to: $(curl -s ifconfig.me 2>/dev/null || echo 'your-droplet-ip')"
    echo ""
    exit 1
fi

DOMAIN="$1"
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "unknown")

echo "Domain: $DOMAIN"
echo "Server IP: $SERVER_IP"

echo ""
echo "📁 1. Creating SSL directory..."
echo "------------------------------"
sudo mkdir -p /etc/ssl/cloudflare

echo ""
echo "🔑 2. Generating origin certificate for Cloudflare..."
echo "----------------------------------------------------"
echo "This creates a certificate that Cloudflare will trust."

# Generate private key
sudo openssl genrsa -out /etc/ssl/cloudflare/origin.key 2048

# Generate certificate signing request
sudo openssl req -new -key /etc/ssl/cloudflare/origin.key -out /etc/ssl/cloudflare/origin.csr \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=$DOMAIN"

# Generate self-signed certificate (Cloudflare will provide the real one)
sudo openssl x509 -req -days 365 -in /etc/ssl/cloudflare/origin.csr \
    -signkey /etc/ssl/cloudflare/origin.key -out /etc/ssl/cloudflare/origin.crt

echo "✅ Origin certificate generated"

echo ""
echo "🔐 3. Setting proper permissions..."
echo "----------------------------------"
sudo chmod 600 /etc/ssl/cloudflare/origin.key
sudo chmod 644 /etc/ssl/cloudflare/origin.crt

echo ""
echo "🔥 4. Updating firewall..."
echo "-------------------------"
sudo ufw allow 443/tcp
sudo ufw allow 80/tcp  # Cloudflare needs both
sudo ufw reload

echo ""
echo "📝 5. Backing up current Nginx config..."
echo "---------------------------------------"
sudo cp /etc/nginx/sites-available/potato /etc/nginx/sites-available/potato.backup.$(date +%Y%m%d_%H%M%S)

echo ""
echo "🌐 6. Creating Cloudflare-compatible Nginx config..."
echo "---------------------------------------------------"
sudo tee /etc/nginx/sites-available/potato > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    # Allow Cloudflare to access via HTTP for flexibility
    # Cloudflare will handle HTTPS termination
    
    # Root redirect to /annotation (if using custom URL)
    location = / {
        return 301 https://\$host/annotation/;
    }

    # Main application at /annotation
    location /annotation/ {
        rewrite ^/annotation/(.*)$ /\$1 break;
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        
        # Cloudflare headers
        proxy_set_header CF-Connecting-IP \$http_cf_connecting_ip;
        proxy_set_header CF-Ray \$http_cf_ray;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        client_max_body_size 100M;
    }

    # Static files
    location /annotation/static/ {
        alias /opt/potato/potato/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    # Origin certificate for Cloudflare
    ssl_certificate /etc/ssl/cloudflare/origin.crt;
    ssl_certificate_key /etc/ssl/cloudflare/origin.key;

    # SSL configuration optimized for Cloudflare
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;

    # Security headers (Cloudflare may override some)
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;

    # Root redirect to /annotation
    location = / {
        return 301 /annotation/;
    }

    # Main application at /annotation
    location /annotation/ {
        rewrite ^/annotation/(.*)$ /\$1 break;
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Host \$host;
        
        # Cloudflare headers
        proxy_set_header CF-Connecting-IP \$http_cf_connecting_ip;
        proxy_set_header CF-Ray \$http_cf_ray;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        client_max_body_size 100M;
    }

    # Static files
    location /annotation/static/ {
        alias /opt/potato/potato/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

echo ""
echo "🧪 7. Testing Nginx configuration..."
echo "-----------------------------------"
sudo nginx -t

if [ $? -eq 0 ]; then
    echo "✅ Nginx configuration is valid"
    
    echo ""
    echo "🔄 8. Restarting Nginx..."
    echo "------------------------"
    sudo systemctl restart nginx
    
    echo ""
    echo "✅ Server configuration complete!"
    echo ""
    echo "🌐 Next steps in Cloudflare Dashboard:"
    echo "======================================="
    echo ""
    echo "1. 📍 DNS Settings:"
    echo "   - Go to DNS tab in Cloudflare"
    echo "   - Ensure A record: $DOMAIN → $SERVER_IP"
    echo "   - Ensure proxy is ENABLED (orange cloud)"
    echo ""
    echo "2. 🔒 SSL/TLS Settings:"
    echo "   - Go to SSL/TLS tab"
    echo "   - Set encryption mode to 'Full' or 'Full (strict)'"
    echo "   - Enable 'Always Use HTTPS'"
    echo ""
    echo "3. 🚀 Optional Optimizations:"
    echo "   - Speed tab: Enable 'Auto Minify' for CSS/JS/HTML"
    echo "   - Caching tab: Set caching level to 'Standard'"
    echo "   - Security tab: Set security level to 'Medium'"
    echo ""
    echo "🌐 Your annotation tool will be available at:"
    echo "   https://$DOMAIN/annotation"
    echo ""
    echo "🔒 Security Features (via Cloudflare):"
    echo "   ✅ SSL/TLS encryption"
    echo "   ✅ DDoS protection"
    echo "   ✅ Web Application Firewall (WAF)"
    echo "   ✅ Bot protection"
    echo "   ✅ CDN acceleration"
    echo ""
    echo "⏱️  DNS propagation may take 5-30 minutes"
    
else
    echo "❌ Nginx configuration test failed!"
    echo "Restoring backup..."
    sudo cp /etc/nginx/sites-available/potato.backup.* /etc/nginx/sites-available/potato
    sudo systemctl restart nginx
    exit 1
fi

echo ""
echo "Cloudflare HTTPS setup complete! 🔒✅"
echo ""
echo "💡 Remember to configure Cloudflare dashboard settings!"
EOF