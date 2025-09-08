#!/bin/bash

# Optimize existing SSL configuration for musicscience.uk
# Run this on your DigitalOcean droplet

set -e

DOMAIN="musicscience.uk"
WWW_DOMAIN="www.musicscience.uk"

echo "🔧 Optimizing SSL configuration for $DOMAIN"
echo "==========================================="

echo ""
echo "📝 1. Backing up current Nginx configuration..."
echo "----------------------------------------------"
sudo cp /etc/nginx/sites-available/potato /etc/nginx/sites-available/potato.backup.$(date +%Y%m%d_%H%M%S)
echo "✅ Backup created"

echo ""
echo "🌐 2. Creating optimized Nginx configuration..."
echo "----------------------------------------------"

# Create optimized SSL configuration
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

    # SSL certificate configuration (managed by Certbot)
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    # Additional SSL security settings
    ssl_session_timeout 1d;
    ssl_session_cache shared:MozTLS:10m;
    ssl_session_tickets off;

    # Security headers
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self';" always;

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
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # File upload size
        client_max_body_size 100M;
        
        # Disable buffering for real-time responses
        proxy_buffering off;
    }

    # Static files for the annotation tool
    location /annotation/static/ {
        alias /opt/potato/potato/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
        
        # Security headers for static files
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
    }

    # Handle /annotation without trailing slash
    location = /annotation {
        return 301 /annotation/;
    }

    # Optional: Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # Optional: Block access to sensitive files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Optional: Block access to backup files
    location ~ ~$ {
        deny all;
        access_log off;
        log_not_found off;
    }
}
EOF

echo "✅ Optimized configuration created"

echo ""
echo "🧪 3. Testing new configuration..."
echo "---------------------------------"
if sudo nginx -t; then
    echo "✅ Nginx configuration test passed"
    
    echo ""
    echo "🔄 4. Applying new configuration..."
    echo "----------------------------------"
    sudo systemctl reload nginx
    
    echo "✅ Nginx reloaded with new configuration"
    
    echo ""
    echo "📊 5. Verifying services..."
    echo "--------------------------"
    echo "Nginx status: $(sudo systemctl is-active nginx)"
    echo "Potato status: $(sudo systemctl is-active potato)"
    
    echo ""
    echo "🌐 6. Testing HTTPS connections..."
    echo "---------------------------------"
    
    # Test main domain
    echo "Testing https://$DOMAIN..."
    if timeout 10 curl -I "https://$DOMAIN" 2>/dev/null | head -1; then
        echo "✅ Main domain HTTPS working"
    else
        echo "❌ Main domain HTTPS failed"
    fi
    
    # Test www domain
    echo "Testing https://$WWW_DOMAIN..."
    if timeout 10 curl -I "https://$WWW_DOMAIN" 2>/dev/null | head -1; then
        echo "✅ WWW domain HTTPS working"
    else
        echo "❌ WWW domain HTTPS failed"
    fi
    
    # Test HTTP redirect
    echo "Testing HTTP to HTTPS redirect..."
    if timeout 10 curl -I "http://$DOMAIN" 2>/dev/null | grep -q "301"; then
        echo "✅ HTTP to HTTPS redirect working"
    else
        echo "❌ HTTP to HTTPS redirect not working"
    fi
    
    echo ""
    echo "✅ SSL optimization complete!"
    echo ""
    echo "🎯 Your secure annotation tool is now available at:"
    echo "   https://$DOMAIN/annotation"
    echo "   https://$WWW_DOMAIN/annotation"
    echo ""
    echo "🔒 Security features enabled:"
    echo "   ✅ TLS 1.2 & 1.3 encryption"
    echo "   ✅ HTTP Strict Transport Security (HSTS)"
    echo "   ✅ Content Security Policy (CSP)"
    echo "   ✅ XSS Protection"
    echo "   ✅ Frame Options (Clickjacking protection)"
    echo "   ✅ Content Type Options"
    echo "   ✅ Referrer Policy"
    echo ""
    echo "📈 Test your SSL security rating:"
    echo "   https://www.ssllabs.com/ssltest/analyze.html?d=$DOMAIN"
    echo ""
    echo "🔧 SSL Management:"
    echo "   Check status: ./ssl-manager.sh status"
    echo "   Monitor certs: ./ssl-manager.sh monitor"
    echo "   Test renewal: sudo certbot renew --dry-run"
    
else
    echo "❌ Nginx configuration test failed!"
    echo "Restoring backup configuration..."
    
    # Find the most recent backup
    BACKUP_FILE=$(ls -t /etc/nginx/sites-available/potato.backup.* | head -1)
    sudo cp "$BACKUP_FILE" /etc/nginx/sites-available/potato
    sudo systemctl reload nginx
    
    echo "✅ Backup configuration restored"
    echo ""
    echo "❌ Optimization failed. Please check the error messages above."
    exit 1
fi

echo ""
echo "Optimization complete! 🔒✅"
EOF