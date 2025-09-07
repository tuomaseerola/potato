#!/bin/bash

# Script to reload Potato configuration changes
# Run this on your DigitalOcean droplet after editing config.yaml

set -e

echo "🔄 Reloading Potato configuration..."
echo "==================================="

APP_DIR="/opt/potato"

echo ""
echo "📋 1. Checking current service configuration:"
echo "--------------------------------------------"
echo "Service command line:"
ps aux | grep flask_server.py | grep -v grep || echo "Service not running"

echo ""
echo "Systemd service ExecStart:"
grep "ExecStart" /etc/systemd/system/potato.service

echo ""
echo "📁 2. Verifying config file location:"
echo "------------------------------------"
if [ -f "$APP_DIR/config.yaml" ]; then
    echo "✅ Config file exists at: $APP_DIR/config.yaml"
    echo "Last modified: $(stat -c '%y' $APP_DIR/config.yaml)"
    echo ""
    echo "Config file size: $(wc -l < $APP_DIR/config.yaml) lines"
else
    echo "❌ Config file not found at $APP_DIR/config.yaml"
    echo "Looking for other config files:"
    find $APP_DIR -name "*.yaml" -o -name "*.yml" | head -5
fi

echo ""
echo "🧪 3. Testing config file syntax:"
echo "--------------------------------"
cd $APP_DIR
if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
    python3 -c "
import yaml
try:
    with open('config.yaml', 'r') as f:
        config = yaml.safe_load(f)
    print('✅ Config file syntax is valid')
    
    # Show key settings
    print(f'Server name: {config.get(\"server_name\", \"Not set\")}')
    print(f'Task name: {config.get(\"annotation_task_name\", \"Not set\")}')
    print(f'Output dir: {config.get(\"output_annotation_dir\", \"Not set\")}')
    print(f'Port: {config.get(\"port\", \"Not set\")}')
    
except Exception as e:
    print(f'❌ Config file error: {e}')
    exit(1)
" || exit 1
else
    echo "❌ Virtual environment not found"
    exit 1
fi

echo ""
echo "🔄 4. Restarting Potato service:"
echo "-------------------------------"
echo "Stopping service..."
sudo systemctl stop potato

echo "Starting service..."
sudo systemctl start potato

# Wait for service to start
sleep 3

echo ""
echo "📊 5. Checking service status:"
echo "-----------------------------"
if sudo systemctl is-active --quiet potato; then
    echo "✅ Service is running"
    sudo systemctl status potato --no-pager -l | head -8
else
    echo "❌ Service failed to start"
    echo "Recent logs:"
    sudo journalctl -u potato -n 10 --no-pager
    exit 1
fi

echo ""
echo "📝 6. Checking recent logs:"
echo "--------------------------"
echo "Last 5 lines from service logs:"
sudo journalctl -u potato -n 5 --no-pager

echo ""
echo "✅ Configuration reload complete!"
echo ""
echo "🌐 Your annotation tool should now reflect the changes at:"
echo "   http://$(curl -s ifconfig.me 2>/dev/null || echo 'your-droplet-ip')"
echo ""
echo "🔍 If changes aren't visible:"
echo "• Clear your browser cache (Ctrl+F5)"
echo "• Check logs: sudo journalctl -u potato -f"
echo "• Verify config: cat $APP_DIR/config.yaml"
echo ""
echo "📋 To see what changed, compare with backup:"
echo "   diff $APP_DIR/config.yaml $APP_DIR/production-config.yaml"
EOF