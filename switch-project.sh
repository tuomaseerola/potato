#!/bin/bash

# Script to switch between different Potato annotation projects
# Run this on your DigitalOcean droplet

set -e

APP_DIR="/opt/potato"

# Function to list available projects
list_projects() {
    echo "📋 Available annotation projects:"
    echo "================================"
    
    local count=1
    for project_dir in $APP_DIR/project-hub/*/; do
        if [ -d "$project_dir" ]; then
            project_name=$(basename "$project_dir")
            if [ "$project_name" != "*.zip" ] && [ -d "$project_dir/configs" ]; then
                echo "$count. $project_name"
                
                # List config files in this project
                config_files=$(find "$project_dir/configs" -name "*.yaml" -o -name "*.yml" 2>/dev/null | wc -l)
                if [ $config_files -gt 0 ]; then
                    echo "   Config files:"
                    find "$project_dir/configs" -name "*.yaml" -o -name "*.yml" 2>/dev/null | while read config; do
                        echo "   - $(basename "$config")"
                    done
                fi
                echo ""
                ((count++))
            fi
        fi
    done
}

# Function to switch to a specific project config
switch_project() {
    local project_path="$1"
    
    if [ ! -f "$project_path" ]; then
        echo "❌ Config file not found: $project_path"
        exit 1
    fi
    
    echo "🔄 Switching to project: $(basename "$project_path")"
    echo "Config file: $project_path"
    
    # Backup current config
    if [ -f "$APP_DIR/config.yaml" ]; then
        cp "$APP_DIR/config.yaml" "$APP_DIR/config.yaml.backup.$(date +%Y%m%d_%H%M%S)"
        echo "✅ Backed up current config"
    fi
    
    # Copy new config
    cp "$project_path" "$APP_DIR/config.yaml"
    echo "✅ Copied new config"
    
    # Fix paths in the config file to work from /opt/potato
    cd "$APP_DIR"
    
    # Update data file paths to be relative to /opt/potato
    sed -i 's|"data_files": \[|"data_files": [|g' config.yaml
    sed -i 's|data/|project-hub/'"$(basename "$(dirname "$(dirname "$project_path")")")"'/data_files/|g' config.yaml
    
    # Update output directory to our standard location
    sed -i 's|"output_annotation_dir": "[^"]*"|"output_annotation_dir": "annotation_output/"|g' config.yaml
    
    echo "✅ Updated file paths"
    
    # Validate the config
    source venv/bin/activate
    python3 -c "
import yaml
try:
    with open('config.yaml', 'r') as f:
        config = yaml.safe_load(f)
    print('✅ Config file is valid')
    print(f'Task: {config.get(\"annotation_task_name\", \"Unknown\")}')
    print(f'Server: {config.get(\"server_name\", \"Unknown\")}')
    
    # Check if data files exist
    data_files = config.get('data_files', [])
    for data_file in data_files:
        import os
        if os.path.exists(data_file):
            print(f'✅ Data file exists: {data_file}')
        else:
            print(f'⚠️  Data file not found: {data_file}')
            
except Exception as e:
    print(f'❌ Config validation failed: {e}')
    exit(1)
"
    
    if [ $? -eq 0 ]; then
        echo "✅ Config validation passed"
        
        # Restart the service
        echo "🔄 Restarting Potato service..."
        sudo systemctl restart potato
        
        sleep 3
        
        if sudo systemctl is-active --quiet potato; then
            echo "✅ Service restarted successfully"
            echo ""
            echo "🎯 New annotation project is now active!"
            echo "🌐 Access it at: http://$(curl -s ifconfig.me 2>/dev/null || echo 'your-droplet-ip')"
        else
            echo "❌ Service failed to start with new config"
            echo "Checking logs:"
            sudo journalctl -u potato -n 10 --no-pager
            
            # Restore backup
            if [ -f "$APP_DIR/config.yaml.backup.$(date +%Y%m%d_%H%M%S)" ]; then
                echo "🔄 Restoring previous config..."
                cp "$APP_DIR/config.yaml.backup.$(date +%Y%m%d_%H%M%S)" "$APP_DIR/config.yaml"
                sudo systemctl restart potato
            fi
        fi
    else
        echo "❌ Config validation failed, not switching"
        # Restore backup if it exists
        if [ -f "$APP_DIR/config.yaml.backup.$(date +%Y%m%d_%H%M%S)" ]; then
            cp "$APP_DIR/config.yaml.backup.$(date +%Y%m%d_%H%M%S)" "$APP_DIR/config.yaml"
        fi
    fi
}

# Main script logic
cd "$APP_DIR"

if [ $# -eq 0 ]; then
    echo "🥔 Potato Project Switcher"
    echo "========================="
    echo ""
    list_projects
    echo "Usage:"
    echo "  $0 <project_name>/<config_file>     # Switch to specific config"
    echo "  $0 list                             # List all projects"
    echo ""
    echo "Examples:"
    echo "  $0 sentiment_analysis/sentiment-analysis.yaml"
    echo "  $0 empathy/empathy.yaml"
    echo "  $0 simple_examples/simple-check-box.yaml"
    
elif [ "$1" = "list" ]; then
    list_projects
    
else
    # Check if it's a full path or relative path
    if [[ "$1" == /* ]]; then
        config_path="$1"
    else
        config_path="$APP_DIR/project-hub/$1"
    fi
    
    switch_project "$config_path"
fi
EOF