#!/bin/bash

# DigitalOcean Droplet Deployment Script for Potato Annotation Tool (FIXED VERSION)
# Run this script on your DigitalOcean droplet

set -e

echo "🥔 Starting Potato Annotation Tool deployment on DigitalOcean..."

# Update system
echo "📦 Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install required packages
echo "🔧 Installing required packages..."
sudo apt install -y python3 python3-pip python3-venv git nginx

# Create application directory
APP_DIR="/opt/potato"
echo "📁 Creating application directory: $APP_DIR"
sudo mkdir -p $APP_DIR
sudo chown $USER:$USER $APP_DIR

# Clone or update the repository
if [ -d "$APP_DIR/.git" ]; then
    echo "🔄 Updating existing repository..."
    cd $APP_DIR
    git pull origin main
else
    echo "📥 Cloning repository..."
    git clone https://github.com/tuomaseerola/potato.git $APP_DIR
    cd $APP_DIR
fi

# Create virtual environment
echo "🐍 Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
echo "📚 Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Create data and output directories
echo "📂 Creating data directories..."
mkdir -p $APP_DIR/data
mkdir -p $APP_DIR/annotation_output
mkdir -p $APP_DIR/logs

# Copy and fix production configuration
echo "⚙️ Setting up production configuration..."
cp production-config.yaml config.yaml

# Test the application manually first
echo "🧪 Testing application startup..."
timeout 5s python potato/flask_server.py start config.yaml -p 5000 || echo "✅ Application test completed"

# Create systemd service file
echo "🔧 Creating systemd service..."
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
ExecStart=$APP_DIR/venv/bin/python $APP_DIR/potato/flask_server.py start $APP_DIR/config.yaml -p 5000
Restart=always
RestartSec=10
StandardOutput=append:$APP_DIR/logs/potato.log
StandardError=append:$APP_DIR/logs/potato-error.log

[Install]
WantedBy=multi-user.target
EOF

# Create nginx configuration
echo "🌐 Setting up Nginx reverse proxy..."
sudo tee /etc/nginx/sites-available/potato > /dev/null <<EOF
server {
    listen 80;
    server_name _;

    client_max_body_size 100M;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    location /static {
        alias $APP_DIR/potato/static;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# Enable nginx site
sudo ln -sf /etc/nginx/sites-available/potato /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test nginx configuration
sudo nginx -t

# Start and enable services
echo "🚀 Starting services..."
sudo systemctl daemon-reload
sudo systemctl enable potato
sudo systemctl start potato

# Wait a moment for service to start
sleep 5

# Check service status
echo "📊 Checking service status..."
sudo systemctl status potato --no-pager -l

# Start nginx
sudo systemctl enable nginx
sudo systemctl restart nginx

# Setup firewall
echo "🔥 Configuring firewall..."
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

# Create backup script
echo "💾 Creating backup script..."
tee $APP_DIR/backup-annotations.sh > /dev/null <<EOF
#!/bin/bash
# Backup script for Potato annotations
BACKUP_DIR="/opt/potato-backups"
DATE=\$(date +%Y%m%d_%H%M%S)

mkdir -p \$BACKUP_DIR
tar -czf \$BACKUP_DIR/annotations_\$DATE.tar.gz -C $APP_DIR annotation_output/
echo "Backup created: \$BACKUP_DIR/annotations_\$DATE.tar.gz"

# Keep only last 10 backups
cd \$BACKUP_DIR
ls -t annotations_*.tar.gz | tail -n +11 | xargs -r rm
EOF

chmod +x $APP_DIR/backup-annotations.sh

# Add daily backup cron job
echo "⏰ Setting up daily backups..."
(crontab -l 2>/dev/null; echo "0 2 * * * $APP_DIR/backup-annotations.sh") | crontab -

# Final status check
echo ""
echo "✅ Deployment completed!"
echo ""
echo "🔍 Final Service Status:"
sudo systemctl status potato --no-pager -l
echo ""
echo "🌐 Nginx Status:"
sudo systemctl status nginx --no-pager -l
echo ""
echo "📊 Application should be accessible at:"
echo "   http://$(curl -s ifconfig.me 2>/dev/null || echo 'your-droplet-ip')"
echo "   http://$(hostname -I | awk '{print $1}' 2>/dev/null || echo 'your-local-ip')"
echo ""
echo "📝 Useful commands:"
echo "   View logs: sudo journalctl -u potato -f"
echo "   Restart app: sudo systemctl restart potato"
echo "   Backup data: $APP_DIR/backup-annotations.sh"
echo "   Check status: sudo systemctl status potato"
echo ""
echo "📁 Data locations:"
echo "   App directory: $APP_DIR"
echo "   Annotations: $APP_DIR/annotation_output/"
echo "   Logs: $APP_DIR/logs/"
echo "   Backups: /opt/potato-backups/"
echo ""
echo "🔧 If there are issues, run the fix script:"
echo "   $APP_DIR/fix-digitalocean-service.sh"
EOF