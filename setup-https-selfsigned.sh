#!/bin/bash

# Setup HTTPS with self-signed SSL certificate
# Run this on your DigitalOcean droplet
# NO DOMAIN REQUIRED - works with IP address

set -e

echo "🔒 Setting up HTTPS with self-signed SSL certificate..."
echo "====================================================="

SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "your-server-ip")
echo "Server IP: $SERVER_IP"

echo ""
echo "📁 1. Creating SSL directory..."
echo "------------------------------"
sudo mkdir -p /etc/ssl/potato
cd /etc/ssl/potato

echo ""
echo "🔑 2. Generating self-signed SSL certificate..."
echo "----------------------------------------------"
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout potato-selfsigned.key \
    -out potato-selfsigned.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/OU=OrgUnit/CN=$SERVER_IP" \
    -addext "subjectAltName=IP:$SERVER_IP"

echo "✅ SSL certificate generated"

echo ""
echo "🔐 3. Setting proper permissions..."
echo "----------------------------------"
sudo chmod 600 /etc/ssl/potato/potato-selfsigned.key
sudo chmod 644 /etc/ssl/potato/potato-selfsigned.crt

echo ""
echo "🔥 4. Updating firewall..."
echo "-------------------------"
sudo ufw allow 443/tcp
sudo ufw reload

echo ""
echo "📝 5. Backing up current Nginx config..."
echo "---------------------------------------"
sudo cp /etc/nginx/sites-available/potato /etc/nginx/sites-available/potato.backup.$(date +%Y%m%d_%H%M%S)

echo ""
echo "🌐 6. Creating HTTPS Nginx configuration..."
echo "------------------------------------------"
sudo tee /etc/nginx/sites-available/potato > /dev/null <<EOF
server {
    listen 80;
    server_name _;
    
    # Redirect HTTP to HTTPS
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name _;

    # Self-signed SSL certificate
    ssl_certificate /etc/ssl/potato/potato-selfsigned.crt;
    ssl_certificate_key /etc/ssl/potato/potato-selfsigned.key;

    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security headers
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Root redirect to /annotation (if using custom URL)
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

    # Alternative: serve at root (uncomment if preferred)
    # location / {
    #     proxy_pass http://127.0.0.1:5000;
    #     proxy_set_header Host \$host;
    #     proxy_set_header X-Real-IP \$remote_addr;
    #     proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    #     proxy_set_header X-Forwarded-Proto https;
    #     client_max_body_size 100M;
    # }
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
    echo "📊 9. Checking services..."
    echo "-------------------------"
    echo "Nginx status:"
    sudo systemctl status nginx --no-pager -l | head -3
    
    echo ""
    echo "Potato service status:"
    sudo systemctl status potato --no-pager -l | head -3
    
    echo ""
    echo "✅ HTTPS setup complete!"
    echo ""
    echo "🌐 Your secure annotation tool is now available at:"
    echo "   https://$SERVER_IP/annotation"
    echo "   (or https://$SERVER_IP if serving at root)"
    echo ""
    echo "⚠️  IMPORTANT - Self-Signed Certificate Warning:"
    echo "   Browsers will show a security warning because this is a self-signed certificate."
    echo "   This is normal and expected. To proceed:"
    echo ""
    echo "   Chrome/Edge: Click 'Advanced' → 'Proceed to $SERVER_IP (unsafe)'"
    echo "   Firefox: Click 'Advanced' → 'Accept the Risk and Continue'"
    echo "   Safari: Click 'Show Details' → 'visit this website'"
    echo ""
    echo "🔒 Security Features:"
    echo "   ✅ TLS 1.2 & 1.3 encryption"
    echo "   ✅ HTTP to HTTPS redirect"
    echo "   ✅ Security headers"
    echo "   ⚠️  Self-signed certificate (browser warnings expected)"
    echo ""
    echo "💡 For production use, consider using Let's Encrypt with a domain name:"
    echo "   ./setup-https-letsencrypt.sh your-domain.com"
    
else
    echo "❌ Nginx configuration test failed!"
    echo "Restoring backup..."
    sudo cp /etc/nginx/sites-available/potato.backup.* /etc/nginx/sites-available/potato
    sudo systemctl restart nginx
    exit 1
fi

echo ""
echo "Self-signed HTTPS setup complete! 🔒✅"
EOF