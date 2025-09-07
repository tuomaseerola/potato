#!/bin/bash

# Setup multiple Potato projects running simultaneously on different ports
# Run this on your DigitalOcean droplet

set -e

APP_DIR="/opt/potato"
BASE_PORT=5000

echo "🚀 Setting up multiple Potato annotation projects..."
echo "=================================================="

# Function to create a service for a specific project
create_project_service() {
    local project_name="$1"
    local config_file="$2"
    local port="$3"
    
    echo "📝 Creating service for $project_name on port $port..."
    
    # Create project-specific config
    local project_config="$APP_DIR/config-$project_name.yaml"
    cp "$config_file" "$project_config"
    
    # Update paths and port in the config
    cd "$APP_DIR"
    sed -i "s|\"port\": [0-9]*|\"port\": $port|g" "$project_config"
    sed -i 's|data/|project-hub/'"$(basename "$(dirname "$(dirname "$config_file")")")"'/data_files/|g' "$project_config"
    sed -i 's|"output_annotation_dir": "[^"]*"|"output_annotation_dir": "annotation_output/'$project_name'/"|g' "$project_config"
    
    # Create output directory
    mkdir -p "$APP_DIR/annotation_output/$project_name"
    chown $USER:$USER "$APP_DIR/annotation_output/$project_name"
    
    # Create systemd service
    sudo tee "/etc/systemd/system/potato-$project_name.service" > /dev/null <<EOF
[Unit]
Description=Potato Annotation Tool - $project_name
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$APP_DIR
Environment=PATH=$APP_DIR/venv/bin
Environment=PYTHONPATH=$APP_DIR
ExecStart=$APP_DIR/venv/bin/python $APP_DIR/potato/flask_server.py start $APP_DIR/config-$project_name.yaml -p $port
Restart=always
RestartSec=10
StandardOutput=append:$APP_DIR/logs/potato-$project_name.log
StandardError=append:$APP_DIR/logs/potato-$project_name-error.log

[Install]
WantedBy=multi-user.target
EOF

    echo "✅ Created service: potato-$project_name"
}

# Function to update Nginx for multiple projects
update_nginx_multi_project() {
    echo "🌐 Updating Nginx configuration for multiple projects..."
    
    # Backup current config
    sudo cp /etc/nginx/sites-available/potato /etc/nginx/sites-available/potato.backup
    
    # Create new multi-project nginx config
    sudo tee /etc/nginx/sites-available/potato > /dev/null <<'EOF'
server {
    listen 80;
    server_name _;

    # Root page with project list
    location = / {
        return 200 '
<!DOCTYPE html>
<html>
<head><title>Potato Annotation Projects</title></head>
<body>
<h1>🥔 Potato Annotation Projects</h1>
<ul>
<li><a href="/sentiment/">Sentiment Analysis</a></li>
<li><a href="/empathy/">Empathy Detection</a></li>
<li><a href="/simple/">Simple Examples</a></li>
</ul>
</body>
</html>';
        add_header Content-Type text/html;
    }

    # Sentiment analysis project
    location /sentiment/ {
        rewrite ^/sentiment/(.*)$ /$1 break;
        proxy_pass http://127.0.0.1:5001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        client_max_body_size 100M;
    }

    # Empathy project
    location /empathy/ {
        rewrite ^/empathy/(.*)$ /$1 break;
        proxy_pass http://127.0.0.1:5002;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        client_max_body_size 100M;
    }

    # Simple examples project
    location /simple/ {
        rewrite ^/simple/(.*)$ /$1 break;
        proxy_pass http://127.0.0.1:5003;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        client_max_body_size 100M;
    }

    # Static files for all projects
    location ~ ^/(sentiment|empathy|simple)/static/(.*)$ {
        alias /opt/potato/potato/static/$2;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

    # Test and reload nginx
    sudo nginx -t && sudo systemctl reload nginx
}

# Main setup
cd "$APP_DIR"

echo ""
echo "📋 Setting up default projects:"
echo "------------------------------"

# Create services for common projects
if [ -f "project-hub/sentiment_analysis/configs/sentiment-analysis.yaml" ]; then
    create_project_service "sentiment" "project-hub/sentiment_analysis/configs/sentiment-analysis.yaml" 5001
fi

if [ -f "project-hub/empathy/configs/empathy.yaml" ]; then
    create_project_service "empathy" "project-hub/empathy/configs/empathy.yaml" 5002
fi

if [ -f "project-hub/simple_examples/configs/simple-check-box.yaml" ]; then
    create_project_service "simple" "project-hub/simple_examples/configs/simple-check-box.yaml" 5003
fi

echo ""
echo "🔄 Reloading systemd and starting services..."
echo "--------------------------------------------"
sudo systemctl daemon-reload

# Start services
for service in sentiment empathy simple; do
    if [ -f "/etc/systemd/system/potato-$service.service" ]; then
        sudo systemctl enable "potato-$service"
        sudo systemctl start "potato-$service"
        echo "✅ Started potato-$service"
    fi
done

# Update nginx
update_nginx_multi_project

echo ""
echo "📊 Service status:"
echo "-----------------"
for service in sentiment empathy simple; do
    if sudo systemctl is-active --quiet "potato-$service" 2>/dev/null; then
        echo "✅ potato-$service: running"
    else
        echo "❌ potato-$service: not running"
    fi
done

echo ""
echo "✅ Multi-project setup complete!"
echo ""
echo "🌐 Access your projects at:"
echo "  http://$(curl -s ifconfig.me 2>/dev/null || echo 'your-droplet-ip')/ - Project list"
echo "  http://$(curl -s ifconfig.me 2>/dev/null || echo 'your-droplet-ip')/sentiment/ - Sentiment Analysis"
echo "  http://$(curl -s ifconfig.me 2>/dev/null || echo 'your-droplet-ip')/empathy/ - Empathy Detection"
echo "  http://$(curl -s ifconfig.me 2>/dev/null || echo 'your-droplet-ip')/simple/ - Simple Examples"
echo ""
echo "📁 Data locations:"
echo "  /opt/potato/annotation_output/sentiment/"
echo "  /opt/potato/annotation_output/empathy/"
echo "  /opt/potato/annotation_output/simple/"
echo ""
echo "🔧 Manage services:"
echo "  sudo systemctl status potato-sentiment"
echo "  sudo systemctl restart potato-empathy"
echo "  sudo journalctl -u potato-simple -f"
EOF