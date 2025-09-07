#!/bin/bash

# Find existing annotation data and fix the configuration
# Run this on your DigitalOcean droplet

set -e

echo "🔍 Finding and fixing Potato annotation data..."
echo "=============================================="

APP_DIR="/opt/potato"
cd $APP_DIR

echo ""
echo "📁 Step 1: Searching for existing annotation data..."
echo "---------------------------------------------------"

# Search for annotation files
echo "Searching for JSON/JSONL files:"
FOUND_FILES=$(find $APP_DIR -name "*.json*" -type f 2>/dev/null)
if [ ! -z "$FOUND_FILES" ]; then
    echo "✅ Found annotation files:"
    echo "$FOUND_FILES"
else
    echo "❌ No JSON files found"
fi

echo ""
echo "Searching for user directories:"
USER_DIRS=$(find $APP_DIR -name "*user*" -type d 2>/dev/null)
if [ ! -z "$USER_DIRS" ]; then
    echo "✅ Found user directories:"
    echo "$USER_DIRS"
    
    # Check contents of user directories
    for dir in $USER_DIRS; do
        echo "Contents of $dir:"
        ls -la "$dir" 2>/dev/null | head -5
    done
else
    echo "❌ No user directories found"
fi

echo ""
echo "📂 Step 2: Checking service working directory..."
echo "-----------------------------------------------"
SERVICE_PID=$(pgrep -f "flask_server.py" | head -1)
if [ ! -z "$SERVICE_PID" ]; then
    WORK_DIR=$(sudo readlink /proc/$SERVICE_PID/cwd 2>/dev/null)
    echo "Service working directory: $WORK_DIR"
    
    if [ ! -z "$WORK_DIR" ] && [ "$WORK_DIR" != "$APP_DIR" ]; then
        echo "⚠️  Service is running from different directory!"
        echo "Checking for data in service working directory:"
        find "$WORK_DIR" -name "*.json*" -o -name "*annotation*" -o -name "*user*" 2>/dev/null | head -10
    fi
else
    echo "❌ Service not running"
fi

echo ""
echo "⚙️ Step 3: Analyzing configuration..."
echo "------------------------------------"
if [ -f "$APP_DIR/config.yaml" ]; then
    echo "Config file exists. Output directory setting:"
    OUTPUT_DIR=$(grep "output_annotation_dir" $APP_DIR/config.yaml | cut -d'"' -f4)
    echo "Configured output directory: $OUTPUT_DIR"
    
    # Check if it's an absolute or relative path
    if [[ "$OUTPUT_DIR" == /* ]]; then
        echo "Using absolute path: $OUTPUT_DIR"
        FULL_OUTPUT_PATH="$OUTPUT_DIR"
    else
        echo "Using relative path: $OUTPUT_DIR"
        FULL_OUTPUT_PATH="$APP_DIR/$OUTPUT_DIR"
    fi
    
    echo "Full output path: $FULL_OUTPUT_PATH"
    
    if [ -d "$FULL_OUTPUT_PATH" ]; then
        echo "✅ Output directory exists"
        echo "Contents:"
        ls -la "$FULL_OUTPUT_PATH" | head -10
    else
        echo "❌ Output directory doesn't exist, creating it..."
        mkdir -p "$FULL_OUTPUT_PATH"
        chown $USER:$USER "$FULL_OUTPUT_PATH"
        echo "✅ Created output directory"
    fi
else
    echo "❌ No config.yaml found"
fi

echo ""
echo "🔧 Step 4: Comprehensive file search..."
echo "--------------------------------------"
echo "All potential annotation files in /opt/potato:"
find $APP_DIR -type f \( -name "*.json*" -o -name "*annotation*" -o -name "*user*" \) 2>/dev/null

echo ""
echo "Recent files (last 2 hours):"
find $APP_DIR -type f -mmin -120 2>/dev/null | head -10

echo ""
echo "🧪 Step 5: Testing annotation save location..."
echo "---------------------------------------------"
# Create a test file to see where the service can write
TEST_DIR="$APP_DIR/annotation_output"
mkdir -p "$TEST_DIR"
chown $USER:$USER "$TEST_DIR"

if echo "test" > "$TEST_DIR/test_write.txt" 2>/dev/null; then
    echo "✅ Can write to $TEST_DIR"
    rm "$TEST_DIR/test_write.txt"
else
    echo "❌ Cannot write to $TEST_DIR"
fi

echo ""
echo "🔄 Step 6: Restarting service with correct permissions..."
echo "-------------------------------------------------------"
# Fix ownership and restart
sudo chown -R $USER:$USER $APP_DIR
sudo systemctl restart potato

sleep 3
echo "Service status:"
sudo systemctl status potato --no-pager -l | head -5

echo ""
echo "📊 Step 7: Summary and next steps..."
echo "-----------------------------------"
echo "Data search complete!"
echo ""
echo "🎯 To find your existing annotations:"
echo "1. Check any file paths listed above"
echo "2. Submit a new annotation and run:"
echo "   watch -n 1 'find /opt/potato -type f -mmin -1 2>/dev/null'"
echo ""
echo "📁 Expected location after fix:"
echo "   /opt/potato/annotation_output/annotated_instances.jsonl"
echo ""
echo "🔍 Monitor for new files:"
echo "   watch -n 1 'ls -la /opt/potato/annotation_output/'"
echo ""
echo "If you found existing data files above, that's where your annotations are!"
EOF