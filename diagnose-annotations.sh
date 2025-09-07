#!/bin/bash

# Diagnostic script for Potato annotation saving issues
# Run this on your DigitalOcean droplet

echo "🔍 Diagnosing Potato annotation saving issues..."
echo "================================================"

APP_DIR="/opt/potato"
cd $APP_DIR

echo ""
echo "📋 1. Configuration Check:"
echo "-------------------------"
echo "Output directory setting:"
grep -A 1 -B 1 "output_annotation_dir" config.yaml || echo "❌ Config not found"

echo ""
echo "Output format setting:"
grep -A 1 -B 1 "output_annotation_format" config.yaml || echo "❌ Format not found"

echo ""
echo "📁 2. Directory Structure:"
echo "-------------------------"
echo "App directory contents:"
ls -la $APP_DIR/ | grep -E "(annotation|config|data)"

echo ""
echo "Annotation output directory:"
if [ -d "$APP_DIR/annotation_output" ]; then
    ls -la $APP_DIR/annotation_output/
    echo "Directory permissions: $(stat -c '%A %U:%G' $APP_DIR/annotation_output/)"
else
    echo "❌ annotation_output directory does not exist!"
    echo "Creating it now..."
    mkdir -p $APP_DIR/annotation_output
    chown $USER:$USER $APP_DIR/annotation_output
    echo "✅ Created annotation_output directory"
fi

echo ""
echo "🔐 3. Permissions Check:"
echo "------------------------"
echo "App directory owner: $(stat -c '%U:%G' $APP_DIR)"
echo "Config file permissions: $(stat -c '%A %U:%G' $APP_DIR/config.yaml 2>/dev/null || echo 'Config file not found')"

echo ""
echo "👤 4. User Context:"
echo "------------------"
echo "Current user: $(whoami)"
echo "Service user: $(grep '^User=' /etc/systemd/system/potato.service | cut -d'=' -f2)"

echo ""
echo "📊 5. Service Status:"
echo "--------------------"
sudo systemctl status potato --no-pager -l | head -10

echo ""
echo "📝 6. Recent Logs:"
echo "-----------------"
echo "Last 10 lines from service logs:"
sudo journalctl -u potato -n 10 --no-pager

echo ""
echo "Application log file:"
if [ -f "$APP_DIR/logs/potato.log" ]; then
    echo "Last 5 lines from potato.log:"
    tail -5 $APP_DIR/logs/potato.log
else
    echo "❌ No application log file found"
fi

echo ""
echo "🧪 7. Test Write Permissions:"
echo "-----------------------------"
TEST_FILE="$APP_DIR/annotation_output/test_write.txt"
if echo "test" > $TEST_FILE 2>/dev/null; then
    echo "✅ Can write to annotation_output directory"
    rm $TEST_FILE
else
    echo "❌ Cannot write to annotation_output directory"
    echo "Fixing permissions..."
    sudo chown -R $USER:$USER $APP_DIR/annotation_output
    chmod 755 $APP_DIR/annotation_output
fi

echo ""
echo "🔧 8. Configuration Validation:"
echo "------------------------------"
cd $APP_DIR
source venv/bin/activate
python3 -c "
import yaml
try:
    with open('config.yaml', 'r') as f:
        config = yaml.safe_load(f)
    print('✅ Config file is valid YAML')
    print(f'Output dir: {config.get(\"output_annotation_dir\", \"NOT SET\")}')
    print(f'Output format: {config.get(\"output_annotation_format\", \"NOT SET\")}')
    
    import os
    output_dir = config.get('output_annotation_dir', 'annotation_output/')
    if os.path.exists(output_dir):
        print(f'✅ Output directory exists: {output_dir}')
        if os.access(output_dir, os.W_OK):
            print('✅ Output directory is writable')
        else:
            print('❌ Output directory is not writable')
    else:
        print(f'❌ Output directory does not exist: {output_dir}')
except Exception as e:
    print(f'❌ Config error: {e}')
" 2>/dev/null || echo "❌ Python validation failed"

echo ""
echo "💡 9. Recommendations:"
echo "---------------------"

if [ ! -d "$APP_DIR/annotation_output" ]; then
    echo "• Create annotation_output directory"
fi

if [ ! -w "$APP_DIR/annotation_output" ]; then
    echo "• Fix directory permissions"
fi

echo "• Try submitting a test annotation through the web interface"
echo "• Check logs after submission: sudo journalctl -u potato -f"
echo "• Monitor the directory: watch -n 1 'ls -la $APP_DIR/annotation_output/'"

echo ""
echo "🎯 Next Steps:"
echo "-------------"
echo "1. Submit an annotation through the web interface"
echo "2. Run: watch -n 1 'ls -la $APP_DIR/annotation_output/'"
echo "3. Check logs: sudo journalctl -u potato -f"
echo "4. If still no files, restart service: sudo systemctl restart potato"

echo ""
echo "Diagnosis complete! 🏁"
EOF