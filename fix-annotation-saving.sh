#!/bin/bash

# Fix script for Potato annotation saving issues
# Run this on your DigitalOcean droplet

set -e

APP_DIR="/opt/potato"
echo "🔧 Fixing Potato annotation saving issues..."

cd $APP_DIR

# 1. Ensure annotation_output directory exists with correct permissions
echo "📁 Creating/fixing annotation_output directory..."
mkdir -p $APP_DIR/annotation_output
sudo chown -R $USER:$USER $APP_DIR/annotation_output
chmod 755 $APP_DIR/annotation_output

# 2. Fix config file if needed
echo "⚙️ Checking configuration..."
if ! grep -q "output_annotation_dir" config.yaml; then
    echo "❌ Config missing output_annotation_dir, fixing..."
    cp production-config.yaml config.yaml
fi

# 3. Ensure the service user matches file ownership
echo "👤 Fixing ownership..."
sudo chown -R $USER:$USER $APP_DIR
SERVICE_USER=$(grep '^User=' /etc/systemd/system/potato.service | cut -d'=' -f2)
if [ "$SERVICE_USER" != "$USER" ]; then
    echo "⚠️  Service user ($SERVICE_USER) differs from current user ($USER)"
    echo "Updating service file..."
    sudo sed -i "s/^User=.*/User=$USER/" /etc/systemd/system/potato.service
    sudo systemctl daemon-reload
fi

# 4. Test write permissions
echo "🧪 Testing write permissions..."
TEST_FILE="$APP_DIR/annotation_output/test_$(date +%s).txt"
if echo "test write" > $TEST_FILE; then
    echo "✅ Write test successful"
    rm $TEST_FILE
else
    echo "❌ Write test failed"
    exit 1
fi

# 5. Restart the service to apply changes
echo "🔄 Restarting Potato service..."
sudo systemctl restart potato

# 6. Wait and check status
sleep 3
echo "📊 Service status:"
sudo systemctl status potato --no-pager -l | head -5

echo ""
echo "✅ Fix completed!"
echo ""
echo "🎯 Next steps:"
echo "1. Go to your annotation tool: http://$(curl -s ifconfig.me 2>/dev/null || echo 'your-droplet-ip')"
echo "2. Submit a test annotation"
echo "3. Check for files: ls -la $APP_DIR/annotation_output/"
echo "4. Monitor in real-time: watch -n 1 'ls -la $APP_DIR/annotation_output/'"
echo ""
echo "📝 If still no files appear, check logs:"
echo "   sudo journalctl -u potato -f"
EOF