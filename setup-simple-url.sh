#!/bin/bash

# Simple URL prefix setup using only Nginx rewriting
# Run this on your DigitalOcean droplet

set -e

echo "🔧 Setting up simple /annotation URL prefix..."
echo "============================================="

# Backup current nginx config
sudo cp /etc/nginx/sites-available/potato /etc/nginx/sites-available/potato.backup

echo "📝 Creating simple Nginx configuration with URL rewriting..."

sudo tee /etc/nginx/sites-available/potato > /dev/null <<'EOF'
server {
    listen 80;
    server_name _;

    # Root redirect to /annotation
    location = / {
        return 301 /annotation/;
    }

    # Main application at /annotation path
    location /annotation/ {
        # Remove /annotation prefix and forward to Flask
        rewrite ^/annotation/(.*)$ /$1 break;
        rewrite ^/annotation$ / break;
        
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        client_max_body_size 100M;
    }

    # Static files at /annotation/static
    location /annotation/static/ {
        alias /opt/potato/potato/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Handle /annotation without trailing slash
    location = /annotation {
        return 301 /annotation/;
    }

    # Optional: Block access to root paths
    location / {
        return 404 "Not found - Access the annotation tool at /annotation";
    }
}
EOF

echo "🧪 Testing Nginx configuration..."
sudo nginx -t

if [ $? -eq 0 ]; then
    echo "✅ Nginx configuration is valid"
    
    echo "🔄 Restarting Nginx..."
    sudo systemctl restart nginx
    
    # Wait a moment
    sleep 2
    
    echo "📊 Checking Nginx status..."
    sudo systemctl status nginx --no-pager -l | head -3
    
    echo ""
    echo "✅ Simple URL setup complete!"
    echo ""
    echo "🌐 Your annotation tool is now available at:"
    echo "   http://$(curl -s ifconfig.me 2>/dev/null || echo 'your-droplet-ip')/annotation"
    echo ""
    echo "📝 What this does:"
    echo "• Accessing / redirects to /annotation/"
    echo "• /annotation/ serves your Potato app"
    echo "• Static files work at /annotation/static/"
    echo "• All other paths return 404"
    echo ""
    echo "🧪 Test it:"
    echo "   curl -I http://$(curl -s ifconfig.me 2>/dev/null || echo 'localhost')/annotation"
    echo ""
    echo "🔧 To revert to original setup:"
    echo "   sudo cp /etc/nginx/sites-available/potato.backup /etc/nginx/sites-available/potato"
    echo "   sudo systemctl restart nginx"
    
else
    echo "❌ Nginx configuration test failed!"
    echo "Restoring backup..."
    sudo cp /etc/nginx/sites-available/potato.backup /etc/nginx/sites-available/potato
    exit 1
fi
EOF