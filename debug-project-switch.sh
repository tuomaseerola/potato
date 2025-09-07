#!/bin/bash

# Debug script for project switching issues
# Run this on your DigitalOcean droplet

set -e

APP_DIR="/opt/potato"
cd $APP_DIR

echo "🔍 Debugging project switch failure..."
echo "===================================="

echo ""
echo "📋 1. Service Status:"
echo "--------------------"
sudo systemctl status potato --no-pager -l

echo ""
echo "📝 2. Detailed Service Logs (last 30 lines):"
echo "--------------------------------------------"
sudo journalctl -u potato -n 30 --no-pager

echo ""
echo "📄 3. Application Log Files:"
echo "----------------------------"
if [ -f "$APP_DIR/logs/potato-error.log" ]; then
    echo "Error log (last 10 lines):"
    tail -10 "$APP_DIR/logs/potato-error.log"
else
    echo "❌ No error log file found"
fi

if [ -f "$APP_DIR/logs/potato.log" ]; then
    echo ""
    echo "Application log (last 10 lines):"
    tail -10 "$APP_DIR/logs/potato.log"
else
    echo "❌ No application log file found"
fi

echo ""
echo "⚙️ 4. Config File Analysis:"
echo "--------------------------"
if [ -f "$APP_DIR/config.yaml" ]; then
    echo "✅ Config file exists"
    echo "File size: $(wc -c < config.yaml) bytes"
    echo "Lines: $(wc -l < config.yaml)"
    echo ""
    
    # Test YAML syntax
    source venv/bin/activate
    python3 -c "
import yaml
import sys
try:
    with open('config.yaml', 'r') as f:
        config = yaml.safe_load(f)
    print('✅ YAML syntax is valid')
    
    # Check required fields
    required_fields = ['annotation_task_name', 'data_files', 'annotation_schemes']
    for field in required_fields:
        if field in config:
            print(f'✅ {field}: present')
        else:
            print(f'❌ {field}: missing')
    
    # Check data files
    data_files = config.get('data_files', [])
    print(f'Data files specified: {len(data_files)}')
    for i, data_file in enumerate(data_files):
        import os
        if os.path.exists(data_file):
            print(f'✅ Data file {i+1}: {data_file} (exists)')
        else:
            print(f'❌ Data file {i+1}: {data_file} (NOT FOUND)')
            
except yaml.YAMLError as e:
    print(f'❌ YAML syntax error: {e}')
    sys.exit(1)
except Exception as e:
    print(f'❌ Config error: {e}')
    sys.exit(1)
" || echo "❌ Config validation failed"

else
    echo "❌ Config file not found!"
fi

echo ""
echo "🧪 5. Manual Test:"
echo "-----------------"
echo "Testing the exact command that the service runs..."
cd $APP_DIR
source venv/bin/activate

echo "Command: python potato/flask_server.py start config.yaml -p 5000"
echo "Output:"
timeout 10s python potato/flask_server.py start config.yaml -p 5000 2>&1 || echo "Manual test completed (timeout or error)"

echo ""
echo "📂 6. Directory Structure:"
echo "-------------------------"
echo "Current directory: $(pwd)"
echo "Contents:"
ls -la | head -10

echo ""
echo "Data files directory:"
if [ -d "project-hub" ]; then
    find project-hub -name "*.csv" -o -name "*.json" -o -name "*.jsonl" | head -5
else
    echo "❌ project-hub directory not found"
fi

echo ""
echo "🔧 7. Potential Fixes:"
echo "---------------------"
echo "Based on the analysis above, try these fixes:"
echo ""
echo "If data files not found:"
echo "  - Check the data_files paths in config.yaml"
echo "  - Ensure data files exist in project-hub/PROJECT_NAME/data_files/"
echo ""
echo "If YAML syntax error:"
echo "  - Check for proper quotes and formatting in config.yaml"
echo "  - Compare with a working config file"
echo ""
echo "If permission errors:"
echo "  - Run: sudo chown -R \$USER:\$USER /opt/potato"
echo "  - Run: chmod 644 /opt/potato/config.yaml"
echo ""
echo "To restore previous working config:"
echo "  - ls /opt/potato/config.yaml.backup.*"
echo "  - cp /opt/potato/config.yaml.backup.LATEST /opt/potato/config.yaml"
echo "  - sudo systemctl restart potato"

echo ""
echo "Debug complete! 🏁"
EOF