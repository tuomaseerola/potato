#!/bin/bash

# Advanced setup with Flask app prefix awareness
# Run this on your DigitalOcean droplet

set -e

echo "🔧 Setting up advanced custom URL with Flask prefix support..."
echo "============================================================"

APP_DIR="/opt/potato"

# Backup current nginx config
sudo cp /etc/nginx/sites-available/potato /etc/nginx/sites-available/potato.backup

echo "📝 Creating Flask-aware Nginx configuration..."

# Create nginx config that properly handles Flask app with prefix
sudo tee /etc/nginx/sites-available/potato > /dev/null <<'EOF'
server {
    listen 80;
    server_name _;

    # Root path redirect to /annotation
    location = / {
        return 301 /annotation/;
    }

    # Main application at /annotation
    location /annotation {
        # Ensure trailing slash
        location = /annotation {
            return 301 /annotation/;
        }
        
        # Forward to Flask with proper headers
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Script-Name /annotation;
        proxy_set_header X-Forwarded-Prefix /annotation;
        
        # Important: Don't rewrite the URL, let Flask handle it
        proxy_redirect off;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        client_max_body_size 100M;
    }

    # Static files
    location /annotation/static/ {
        alias $APP_DIR/potato/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Health check endpoint
    location /health {
        return 200 "OK";
        add_header Content-Type text/plain;
    }
}
EOF

echo "🐍 Creating Flask app wrapper for URL prefix..."

# Create a wrapper script that adds URL prefix support
tee $APP_DIR/flask_with_prefix.py > /dev/null <<'EOF'
#!/usr/bin/env python3
"""
Flask wrapper to handle URL prefix for Potato annotation tool
"""
import os
import sys
from werkzeug.middleware.dispatcher import DispatcherMiddleware
from werkzeug.wrappers import Response

# Add the potato directory to Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'potato'))

# Import the original Flask app
from flask_server import app

def simple_app(environ, start_response):
    """Simple WSGI app for non-annotation paths"""
    response = Response('Potato Annotation Tool - Access at /annotation/', 
                       status=200, mimetype='text/plain')
    return response(environ, start_response)

# Create the application with URL prefix
application = DispatcherMiddleware(simple_app, {
    '/annotation': app
})

if __name__ == '__main__':
    from werkzeug.serving import run_simple
    run_simple('0.0.0.0', 5000, application, use_reloader=False, use_debugger=False)
EOF

chmod +x $APP_DIR/flask_with_prefix.py

echo "🔧 Updating systemd service to use prefix-aware Flask..."

# Update systemd service to use the new wrapper
sudo tee /etc/systemd/system/potato.service > /dev/null <<EOF
[Unit]
Description=Potato Annotation Tool
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$APP_DIR
Environment=PATH=$APP_DIR/venv/bin
Environment=PYTHONPATH=$APP_DIR
Environment=SCRIPT_NAME=/annotation
ExecStart=$APP_DIR/venv/bin/python $APP_DIR/flask_with_prefix.py
Restart=always
RestartSec=10
StandardOutput=append:$APP_DIR/logs/potato.log
StandardError=append:$APP_DIR/logs/potato-error.log

[Install]
WantedBy=multi-user.target
EOF

echo "🧪 Testing configurations..."

# Test nginx config
sudo nginx -t
if [ $? -ne 0 ]; then
    echo "❌ Nginx configuration test failed!"
    sudo cp /etc/nginx/sites-available/potato.backup /etc/nginx/sites-available/potato
    exit 1
fi

echo "🔄 Restarting services..."

# Reload and restart services
sudo systemctl daemon-reload
sudo systemctl restart potato
sudo systemctl restart nginx

# Wait for services to start
sleep 5

echo "📊 Checking service status..."
echo "Potato service:"
sudo systemctl status potato --no-pager -l | head -3

echo ""
echo "Nginx service:"
sudo systemctl status nginx --no-pager -l | head -3

echo ""
echo "✅ Advanced setup complete!"
echo ""
echo "🌐 Your annotation tool is now available at:"
echo "   http://$(curl -s ifconfig.me 2>/dev/null || echo 'your-droplet-ip')/annotation"
echo ""
echo "📝 Features:"
echo "• Root URL (/) redirects to /annotation/"
echo "• Flask app is aware of the /annotation prefix"
echo "• All internal links work correctly"
echo "• Static files served from /annotation/static/"
echo ""
echo "🔧 To revert:"
echo "   sudo cp /etc/nginx/sites-available/potato.backup /etc/nginx/sites-available/potato"
echo "   # Restore original systemd service"
echo "   sudo systemctl restart nginx potato"
EOF