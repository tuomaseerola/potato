#!/bin/bash

# Debug the actual configuration being used by the Potato service
# Run this on your DigitalOcean droplet

echo "🔧 Debugging Potato configuration..."
echo "===================================="

APP_DIR="/opt/potato"

echo ""
echo "📋 1. Service configuration:"
echo "---------------------------"
echo "Systemd service file:"
cat /etc/systemd/system/potato.service

echo ""
echo "📂 2. Working directory contents:"
echo "--------------------------------"
echo "Contents of /opt/potato:"
ls -la $APP_DIR/ | head -10

echo ""
echo "⚙️ 3. Config file analysis:"
echo "--------------------------"
if [ -f "$APP_DIR/config.yaml" ]; then
    echo "✅ Config file exists at $APP_DIR/config.yaml"
    echo ""
    echo "Output directory setting:"
    grep -A 3 -B 1 "output_annotation" $APP_DIR/config.yaml
    echo ""
    echo "Data files setting:"
    grep -A 3 -B 1 "data_files" $APP_DIR/config.yaml
else
    echo "❌ No config.yaml found at $APP_DIR/config.yaml"
    echo "Looking for other config files:"
    find $APP_DIR -name "*.yaml" -o -name "*.yml" | head -5
fi

echo ""
echo "🔍 4. Process information:"
echo "-------------------------"
SERVICE_PID=$(pgrep -f "flask_server.py" | head -1)
if [ ! -z "$SERVICE_PID" ]; then
    echo "Service PID: $SERVICE_PID"
    echo "Command line:"
    ps -p $SERVICE_PID -o args --no-headers
    echo ""
    echo "Working directory:"
    sudo readlink /proc/$SERVICE_PID/cwd 2>/dev/null || echo "Cannot read working directory"
    echo ""
    echo "Environment variables:"
    sudo cat /proc/$SERVICE_PID/environ 2>/dev/null | tr '\0' '\n' | grep -E "(PATH|PYTHON|PWD)" | head -5
else
    echo "❌ Service not running"
fi

echo ""
echo "📝 5. Recent service logs:"
echo "-------------------------"
echo "Last 10 lines from service:"
sudo journalctl -u potato -n 10 --no-pager

echo ""
echo "🧪 6. Test config loading:"
echo "-------------------------"
cd $APP_DIR
if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
    echo "Testing config file loading:"
    python3 -c "
import yaml
import os
try:
    with open('config.yaml', 'r') as f:
        config = yaml.safe_load(f)
    print('✅ Config loaded successfully')
    print(f'Output dir: {config.get(\"output_annotation_dir\", \"NOT SET\")}')
    print(f'Working dir: {os.getcwd()}')
    
    # Check if output dir exists relative to current directory
    output_dir = config.get('output_annotation_dir', 'annotation_output/')
    full_path = os.path.abspath(output_dir)
    print(f'Full output path: {full_path}')
    print(f'Directory exists: {os.path.exists(full_path)}')
    
    if os.path.exists(full_path):
        files = os.listdir(full_path)
        print(f'Files in output dir: {files[:5]}')
    
except Exception as e:
    print(f'❌ Config error: {e}')
" 2>/dev/null || echo "Python test failed"
else
    echo "❌ Virtual environment not found"
fi

echo ""
echo "💡 7. Recommendations:"
echo "---------------------"
echo "Based on the above output:"
echo "• Check if the working directory matches the config path"
echo "• Verify the output_annotation_dir setting"
echo "• Look for files in the actual working directory"
echo ""
echo "Next steps:"
echo "1. Run: find /opt/potato -name '*.json*' -type f"
echo "2. Check: ls -la \$(sudo readlink /proc/\$(pgrep flask_server)/cwd)/annotation_output/"
echo "3. Monitor: watch -n 1 'find /opt/potato -type f -mmin -1'"
EOF