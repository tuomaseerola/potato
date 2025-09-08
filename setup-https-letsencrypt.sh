#!/bin/bash

# Setup HTTPS with Let's Encrypt SSL certificates
# Run this on your DigitalOcean droplet
# REQUIRES: A domain name pointing to your droplet IP

set -e

echo "🔒 Setting up HTTPS with Let's Encrypt SSL..."
echo "============================================"

# Check if domain is provided
if [ $# -eq 0 ]; then
    echo "❌ Domain name required!"
    echo ""
    echo "Usage: $0 your-domain.com"
    echo ""
    echo "Before running this script:"
    echo "1. Point your domain to this server's IP: $(curl -s ifconfig.me 2>/dev/null || echo 'your-droplet-ip')"
    echo "2. Wait for DNS propagation (5-30 minutes)"
    echo "3. Test with: ping your-domain.com"
    echo ""
    exit 1
fi

DOMAIN="$1"
EMAIL="admin@$DOMAIN"  # Change this to your email

echo "Domain: $DOMAIN"
echo "Email: $EMAIL"
echo "Server IP: $(curl -s ifconfig.me 2>/dev/null || echo 'unknown')"

# Verify domain points to this server
echo ""
echo "🔍 Verifying domain DNS..."
DOMAIN_IP=$(dig +short "$DOMAIN" 2>/dev/null || echo "")
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "")

if [ "$DOMAIN_IP" != "$SERVER_IP" ]; then
    echo "⚠️  WARNING: Domain $DOMAIN resolves to $DOMAIN_IP"
    echo "   But this server IP is: $SERVER_IP"
    echo ""
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo "✅ Domain correctly points to this server"
fi

echo ""
echo "📦 1. Installing Certbot..."
echo "---------------------------"
sudo apt update
sudo apt install -y certbot python3-certbot-nginx

echo ""
echo "🔥 2. Updating firewall for HTTPS..."
echo "-----------------------------------"
sudo ufw allow 443/tcp
sudo ufw allow 80/tcp  # Needed for Let's Encrypt verification
sudo ufw reload

echo ""
echo "📝 3. Backing up current Nginx config..."
echo "---------------------------------------"
sudo cp /etc/nginx/sites-available/potato /etc/nginx/sites-available/potato.backup.$(date +%Y%m%d_%H%M%S)

echo ""
echo "🌐 4. Creating HTTPS-ready Nginx config..."
echo "-----------------------------------------"
sudo tee /etc/nginx/sites-available/potato > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    # Redirect all HTTP to HTTPS
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    # SSL certificates (will be added by certbot)
    # ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Root redirect to /annotation if you have custom URL setup
    location = / {
        return 301 /annotation/;
    }

    # Main application
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

    # Alternative: serve directly at root (uncomment if preferred)
    # location / {
    #     proxy_pass http://127.0.0.1:5000;
    #     proxy_set_header Host \$host;
    #     proxy_set_header X-Real-IP \$remote_addr;
    #     proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    #     proxy_set_header X-Forwarded-Proto https;
    #     proxy_set_header X-Forwarded-Host \$host;
    #     client_max_body_size 100M;
    # }
}
EOF

echo ""
echo "🧪 5. Testing Nginx configuration..."
echo "-----------------------------------"
sudo nginx -t

if [ $? -ne 0 ]; then
    echo "❌ Nginx configuration test failed!"
    echo "Restoring backup..."
    sudo cp /etc/nginx/sites-available/potato.backup.* /etc/nginx/sites-available/potato
    exit 1
fi

echo ""
echo "🔄 6. Reloading Nginx..."
echo "-----------------------"
sudo systemctl reload nginx

echo ""
echo "🔒 7. Obtaining SSL certificate..."
echo "---------------------------------"
echo "This may take a few minutes..."

# Stop nginx temporarily for standalone verification
sudo systemctl stop nginx

# Get certificate using standalone mode
sudo certbot certonly --standalone \
    --non-interactive \
    --agree-tos \
    --email "$EMAIL" \
    -d "$DOMAIN"

if [ $? -eq 0 ]; then
    echo "✅ SSL certificate obtained successfully!"
    
    # Update nginx config with SSL certificate paths
    sudo sed -i "s|# ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;|ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;|" /etc/nginx/sites-available/potato
    sudo sed -i "s|# ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;|ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;|" /etc/nginx/sites-available/potato
    
    # Start nginx
    sudo systemctl start nginx
    
    echo ""
    echo "🔄 8. Setting up automatic renewal..."
    echo "-----------------------------------"
    
    # Create renewal hook to reload nginx
    sudo tee /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh > /dev/null <<'EOF'
#!/bin/bash
systemctl reload nginx
EOF
    sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh
    
    # Test automatic renewal
    echo "Testing automatic renewal..."
    sudo certbot renew --dry-run
    
    if [ $? -eq 0 ]; then
        echo "✅ Automatic renewal test passed!"
    else
        echo "⚠️  Automatic renewal test failed, but certificate is still valid"
    fi
    
    echo ""
    echo "✅ HTTPS setup complete!"
    echo ""
    echo "🌐 Your secure annotation tool is now available at:"
    echo "   https://$DOMAIN"
    echo ""
    echo "🔒 SSL Certificate Details:"
    echo "   Domain: $DOMAIN"
    echo "   Expires: $(sudo certbot certificates | grep "Expiry Date" | head -1 | cut -d: -f2-)"
    echo "   Auto-renewal: Enabled (runs twice daily)"
    echo ""
    echo "📊 Security Features Enabled:"
    echo "   ✅ TLS 1.2 & 1.3"
    echo "   ✅ HTTP to HTTPS redirect"
    echo "   ✅ Security headers (HSTS, XSS protection, etc.)"
    echo "   ✅ Automatic certificate renewal"
    echo ""
    echo "🔧 Management Commands:"
    echo "   Check certificate: sudo certbot certificates"
    echo "   Renew manually: sudo certbot renew"
    echo "   Test renewal: sudo certbot renew --dry-run"
    
else
    echo "❌ Failed to obtain SSL certificate!"
    echo ""
    echo "Common issues:"
    echo "1. Domain doesn't point to this server"
    echo "2. Port 80 is blocked"
    echo "3. DNS hasn't propagated yet"
    echo ""
    echo "Restoring HTTP-only configuration..."
    sudo cp /etc/nginx/sites-available/potato.backup.* /etc/nginx/sites-available/potato
    sudo systemctl start nginx
    exit 1
fi

echo ""
echo "HTTPS setup complete! 🔒✅"
EOF