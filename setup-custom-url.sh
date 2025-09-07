#!/bin/bash

# Setup custom URL path /annotation for Potato
# Run this on your DigitalOcean droplet

set -e

echo "🔧 Setting up custom URL path /annotation..."
echo "==========================================="

# Backup current nginx config
sudo cp /etc/nginx/sites-available/potato /etc/nginx/sites-available/potato.backup

echo "📝 Creating new Nginx configuration..."

# Create new nginx config with /annotation path
sudo tee /etc/nginx/sites-available/potato > /dev/null <<'EOF'
server {
    listen 80;
    server_name _;

    # Root path redirect to /annotation
    location = / {
        return 301 /annotation/;
    }

    # Main application at /annotation
    location /annotation/ {
        # Remove /annotation prefix before forwarding to Flask
        rewrite ^/annotation/(.*)$ /$1 break;
        
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Script-Name /annotation;
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

    # Optional: serve other content at root if needed
    location / {
        return 404;
    }
}
EOF

echo "🧪 Testing Nginx configuration..."
sudo nginx -t

if [ $? -eq 0 ]; then
    echo "✅ Nginx configuration is valid"
    
    echo "🔄 Restarting Nginx..."
    sudo systemctl restart nginx
    
    echo "📊 Checking Nginx status..."
    sudo systemctl status nginx --no-pager -l | head -5
    
    echo ""
    echo "✅ Setup complete!"
    echo ""
    echo "🌐 Your annotation tool is now available at:"
    echo "   http://$(curl -s ifconfig.me 2>/dev/null || echo 'your-droplet-ip')/annotation"
    echo ""
    echo "📝 Notes:"
    echo "• Root URL (/) redirects to /annotation/"
    echo "• All app functionality works under /annotation path"
    echo "• Static files are served from /annotation/static/"
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