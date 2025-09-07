#!/bin/bash

# Check common locations where Potato might be saving data
# Run this on your DigitalOcean droplet

echo "🔍 Checking common data storage locations..."
echo "==========================================="

# Common locations where data might be saved
LOCATIONS=(
    "/opt/potato/annotation_output"
    "/opt/potato"
    "/tmp"
    "/var/tmp" 
    "$HOME"
    "/root"
    "$(pwd)"
)

echo ""
echo "📁 Checking each possible location:"
echo "----------------------------------"

for location in "${LOCATIONS[@]}"; do
    echo ""
    echo "🔎 Checking: $location"
    if [ -d "$location" ]; then
        # Look for annotation-related files
        find "$location" -maxdepth 3 -name "*.json*" -o -name "*annotation*" -o -name "*user*" 2>/dev/null | head -5
        
        # Look for recently modified files
        echo "Recent files (last hour):"
        find "$location" -maxdepth 2 -type f -mmin -60 2>/dev/null | head -3
    else
        echo "❌ Directory doesn't exist"
    fi
done

echo ""
echo "🔧 Checking service working directory:"
echo "-------------------------------------"
SERVICE_PID=$(pgrep -f "flask_server.py" | head -1)
if [ ! -z "$SERVICE_PID" ]; then
    WORK_DIR=$(sudo readlink /proc/$SERVICE_PID/cwd 2>/dev/null)
    echo "Service working directory: $WORK_DIR"
    if [ ! -z "$WORK_DIR" ] && [ -d "$WORK_DIR" ]; then
        echo "Files in working directory:"
        ls -la "$WORK_DIR" | grep -E "(json|annotation|user|output)" | head -5
        
        echo "Subdirectories:"
        find "$WORK_DIR" -maxdepth 2 -type d | grep -E "(annotation|output|user)" | head -5
    fi
else
    echo "❌ Service not running"
fi

echo ""
echo "📊 Summary of findings:"
echo "----------------------"
echo "Run this to see all potential data files:"
echo "find /opt/potato -name '*.json*' -o -name '*user*' -type f 2>/dev/null"
echo ""
echo "To monitor file creation in real-time:"
echo "watch -n 1 'find /opt/potato -type f -mmin -1 2>/dev/null'"
EOF