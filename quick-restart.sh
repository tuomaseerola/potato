#!/bin/bash

# Quick script to restart Potato service after config changes
# Run this on your DigitalOcean droplet

echo "🔄 Quick restart of Potato service..."

# Restart the service
sudo systemctl restart potato

# Wait a moment
sleep 3

# Check status
if sudo systemctl is-active --quiet potato; then
    echo "✅ Service restarted successfully"
    echo ""
    echo "🌐 Access your updated annotation tool at:"
    echo "   http://$(curl -s ifconfig.me 2>/dev/null || echo 'your-droplet-ip')"
    echo ""
    echo "💡 If you don't see changes, clear browser cache (Ctrl+F5)"
else
    echo "❌ Service failed to restart"
    echo "Checking logs:"
    sudo journalctl -u potato -n 10 --no-pager
fi
EOF