#!/bin/bash

# Fix for DigitalOcean Potato Service
# Run this script on your droplet to fix the systemd service

set -e

APP_DIR="/opt/potato"

echo "🔧 Fixing Potato systemd service..."

# Stop the current service
sudo systemctl stop potato || true

# Create corrected systemd service file
echo "📝 Creating corrected systemd service..."
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

# Test the command manually first
echo "🧪 Testing the command manually..."
cd $APP_DIR
source venv/bin/activate

# Check if config file exists
if [ ! -f "$APP_DIR/config.yaml" ]; then
    echo "📋 Creating config.yaml from production template..."
    cp production-config.yaml config.yaml
fi

# Test the Python command
echo "🐍 Testing Python command..."
timeout 5s python potato/flask_server.py start config.yaml -p 5000 || echo "Command test completed (timeout expected)"

# Reload systemd and start service
echo "🔄 Reloading systemd and starting service..."
sudo systemctl daemon-reload
sudo systemctl enable potato
sudo systemctl start potato

# Wait a moment and check status
sleep 3
echo "📊 Service status:"
sudo systemctl status potato --no-pager -l

echo ""
echo "📝 If there are still issues, check logs with:"
echo "   sudo journalctl -u potato -f"
echo ""
echo "🧪 To test manually:"
echo "   cd $APP_DIR"
echo "   source venv/bin/activate"
echo "   python potato/flask_server.py start config.yaml -p 5000"
EOF