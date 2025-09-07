#!/bin/bash

# Script to find where Potato is actually saving annotation data
# Run this on your DigitalOcean droplet

echo "🔍 Searching for Potato annotation data..."
echo "========================================"

APP_DIR="/opt/potato"

echo ""
echo "📁 1. Searching for annotation files in /opt/potato:"
echo "---------------------------------------------------"
find $APP_DIR -name "*.json*" -type f 2>/dev/null | head -20
find $APP_DIR -name "*annotation*" -type f 2>/dev/null | head -10

echo ""
echo "📂 2. Looking for user directories:"
echo "----------------------------------"
find $APP_DIR -name "*user*" -type d 2>/dev/null
find $APP_DIR -name "*anonymous*" -type d 2>/dev/null

echo ""
echo "🔎 3. Searching for recent files (last 24 hours):"
echo "------------------------------------------------"
find $APP_DIR -type f -mtime -1 2>/dev/null | grep -E "\.(json|jsonl|csv|tsv)$" | head -10

echo ""
echo "⚙️ 4. Checking what config file is actually being used:"
echo "------------------------------------------------------"
ps aux | grep flask_server.py | grep -v grep
echo ""
echo "Config file references in logs:"
sudo journalctl -u potato -n 50 --no-pager | grep -i config | tail -5

echo ""
echo "📋 5. Current working directory of the service:"
echo "----------------------------------------------"
SERVICE_PID=$(pgrep -f "flask_server.py" | head -1)
if [ ! -z "$SERVICE_PID" ]; then
    echo "Service PID: $SERVICE_PID"
    echo "Working directory: $(sudo readlink /proc/$SERVICE_PID/cwd 2>/dev/null || echo 'Cannot read')"
    echo "Open files:"
    sudo lsof -p $SERVICE_PID 2>/dev/null | grep -E "\.(json|yaml|csv)" | head -5
else
    echo "❌ Service not running or PID not found"
fi

echo ""
echo "🗂️ 6. Checking all directories in /opt/potato:"
echo "----------------------------------------------"
find $APP_DIR -type d | head -20

echo ""
echo "📄 7. Looking for files containing annotation data:"
echo "-------------------------------------------------"
# Search for files that might contain your test annotations
find $APP_DIR -name "*.json" -exec grep -l "positive\|negative\|neutral" {} \; 2>/dev/null | head -5

echo ""
echo "🔧 8. Checking current config content:"
echo "-------------------------------------"
if [ -f "$APP_DIR/config.yaml" ]; then
    echo "Config file exists at $APP_DIR/config.yaml"
    echo "Output directory setting:"
    grep -A 2 -B 2 "output_annotation" $APP_DIR/config.yaml 2>/dev/null || echo "Not found in config"
else
    echo "❌ No config.yaml found at $APP_DIR/config.yaml"
fi

echo ""
echo "🌍 9. System-wide search for recent annotation files:"
echo "----------------------------------------------------"
echo "Searching system-wide (this may take a moment)..."
sudo find / -name "*.jsonl" -type f -mtime -1 2>/dev/null | grep -v -E "(proc|sys|dev)" | head -5
sudo find / -name "*annotation*" -type f -mtime -1 2>/dev/null | grep -v -E "(proc|sys|dev)" | head -5

echo ""
echo "💡 10. Recommendations:"
echo "----------------------"
echo "If files were found above, that's where your data is!"
echo "If no files found, the data might be:"
echo "• Stored in memory only (lost on restart)"
echo "• Saved to a different location"
echo "• Not being saved due to permissions"
echo ""
echo "Next steps:"
echo "1. Check any file paths shown above"
echo "2. Look at the service working directory"
echo "3. Verify the config file being used"
echo ""
echo "Search complete! 🏁"
EOF