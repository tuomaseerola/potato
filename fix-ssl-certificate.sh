#!/bin/bash

# Fix SSL certificate issues for musicscience.uk
# Run this on your DigitalOcean droplet

set -e

DOMAIN="musicscience.uk"
WWW_DOMAIN="www.musicscience.uk"
EMAIL="admin@$DOMAIN"  # Change this to your actual email

echo "🔧 Fixing SSL Certificate Issues for $DOMAIN"
echo "============================================="

echo ""
echo "⚠️  This script will:"
echo "   1. Delete the existing certificate"
echo "   2. Create a new trusted certificate"
echo "   3. Update Nginx configuration"
echo "   4. Test the new setup"
echo ""
read -p "Continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "📋 1. Checking current setup..."
echo "------------------------------"
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "unknown")
DOMAIN_IP=$(dig +short "$DOMAIN" 2>/dev/null || echo "FAILED")

echo "Server IP: $SERVER_IP"
echo "Domain IP: $DOMAIN_IP"

if [ "$DOMAIN_IP" != "$SERVER_IP" ]; then
    echo ""
    echo "❌ WARNING: DNS Issue Detected!"
    echo "   $DOMAIN resolves to $DOMAIN_IP"
    echo "   But this server IP is $SERVER_IP"
    echo ""
    echo "You need to update your DNS records at Namecheap:"
    echo "   1. Go to Namecheap dashboard"
    echo "   2. Find $DOMAIN"
    echo "   3. Update A record to point to $SERVER_IP"
    echo "   4. Update www A record to point to $SERVER_IP"
    echo "   5. Wait 5-30 minutes for DNS propagation"
    echo ""
    read -p "Have you fixed the DNS and want to continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Please fix DNS first, then run this script again."
        exit 1
    fi
fi

echo ""
echo "🗑️ 2. Removing existing certificate..."
echo "-------------------------------------"
if sudo certbot certificates 2>/dev/null | grep -q "$DOMAIN"; then
    echo "Deleting existing certificate for $DOMAIN..."
    sudo certbot delete --cert-name "$DOMAIN" --non-interactive
    echo "✅ Existing certificate deleted"
else
    echo "No existing certificate found for $DOMAIN"
fi

echo ""
echo "🛑 3. Stopping Nginx temporarily..."
echo "----------------------------------"
sudo systemctl stop nginx

echo ""
echo "🔒 4. Creating new SSL certificate..."
echo "-----------------------------------"
echo "This may take a few minutes..."

# Use standalone mode to avoid conflicts
if sudo certbot certonly \
    --standalone \
    --non-interactive \
    --agree-tos \
    --email "$EMAIL" \
    -d "$DOMAIN" \
    -d "$WWW_DOMAIN"; then
    
    echo "✅ New SSL certificate created successfully!"
else
    echo "❌ Certificate creation failed!"
    echo ""
    echo "Common causes:"
    echo "1. DNS not pointing to this server"
    echo "2. Port 80 blocked by firewall"
    echo "3. Another service using port 80"
    echo ""
    echo "Starting Nginx back up..."
    sudo systemctl start nginx
    exit 1
fi

echo ""
echo "🌐 5. Creating optimized Nginx configuration..."
echo "----------------------------------------------"

# Backup current config
sudo cp /etc/nginx/sites-available/potato /etc/nginx/sites-available/potato.backup.$(date +%Y%m%d_%H%M%S)

# Create new optimized config
sudo tee /etc/nginx/sites-available/potato > /dev/null <<EOF
# HTTP server - redirect to HTTPS
server {
    listen 80;
    server_name $DOMAIN $WWW_DOMAIN;
    
    # Redirect all HTTP requests to HTTPS
    return 301 https://\$server_name\$request_uri;
}

# HTTPS server
server {
    listen 443 ssl http2;
    server_name $DOMAIN $WWW_DOMAIN;

    # SSL certificate configuration
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    # Include Let's Encrypt recommended SSL settings
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    # Additional security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Root redirect to annotation tool
    location = / {
        return 301 /annotation/;
    }

    # Main Potato annotation application
    location /annotation/ {
        # Remove /annotation prefix before forwarding to Flask
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
        proxy_buffering off;
    }

    # Static files
    location /annotation/static/ {
        alias /opt/potato/potato/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Handle /annotation without trailing slash
    location = /annotation {
        return 301 /annotation/;
    }

    # Health check
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

echo "✅ Nginx configuration created"

echo ""
echo "🧪 6. Testing Nginx configuration..."
echo "-----------------------------------"
if sudo nginx -t; then
    echo "✅ Nginx configuration is valid"
else
    echo "❌ Nginx configuration test failed!"
    echo "Restoring backup..."
    sudo cp /etc/nginx/sites-available/potato.backup.* /etc/nginx/sites-available/potato
    sudo systemctl start nginx
    exit 1
fi

echo ""
echo "🚀 7. Starting services..."
echo "-------------------------"
sudo systemctl start nginx
sudo systemctl restart potato

echo ""
echo "📊 8. Verifying services..."
echo "--------------------------"
sleep 3

echo "Nginx: $(sudo systemctl is-active nginx)"
echo "Potato: $(sudo systemctl is-active potato)"

echo ""
echo "🌐 9. Testing HTTPS connections..."
echo "---------------------------------"

# Test main domain
echo "Testing https://$DOMAIN..."
if timeout 15 curl -I "https://$DOMAIN" 2>/dev/null | head -1; then
    echo "✅ Main domain HTTPS working"
else
    echo "❌ Main domain HTTPS failed"
fi

# Test www domain
echo ""
echo "Testing https://$WWW_DOMAIN..."
if timeout 15 curl -I "https://$WWW_DOMAIN" 2>/dev/null | head -1; then
    echo "✅ WWW domain HTTPS working"
else
    echo "❌ WWW domain HTTPS failed"
fi

# Test HTTP redirect
echo ""
echo "Testing HTTP to HTTPS redirect..."
if timeout 10 curl -I "http://$DOMAIN" 2>/dev/null | grep -q "301"; then
    echo "✅ HTTP to HTTPS redirect working"
else
    echo "❌ HTTP to HTTPS redirect not working"
fi

echo ""
echo "🔒 10. Certificate verification..."
echo "--------------------------------"
echo "Certificate details:"
sudo openssl x509 -in "/etc/letsencrypt/live/$DOMAIN/cert.pem" -noout -subject -dates

echo ""
echo "Subject Alternative Names:"
sudo openssl x509 -in "/etc/letsencrypt/live/$DOMAIN/cert.pem" -noout -text | grep -A 1 "Subject Alternative Name"

echo ""
echo "✅ SSL Certificate Fix Complete!"
echo ""
echo "🎯 Your secure annotation tool is now available at:"
echo "   https://$DOMAIN/annotation"
echo "   https://$WWW_DOMAIN/annotation"
echo ""
echo "🔍 Test your SSL security rating (wait 5-10 minutes):"
echo "   https://www.ssllabs.com/ssltest/analyze.html?d=$DOMAIN"
echo ""
echo "📋 Certificate will auto-renew every 90 days"
echo "🔧 Monitor with: ./ssl-manager.sh monitor"

echo ""
echo "SSL fix complete! 🔒✅"
EOF