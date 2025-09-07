#!/bin/bash

# Improved script to switch between different Potato annotation projects
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
                if [ -d "$project_dir/configs" ]; then
                    echo "   Config files:"
                    find "$project_dir/configs" -name "*.yaml" -o -name "*.yml" 2>/dev/null | while read config; do
                        echo "   - $(basename "$config")"
                    done
                fi
                
                # Check if data files exist
                if [ -d "$project_dir/data_files" ]; then
                    data_count=$(find "$project_dir/data_files" -name "*.csv" -o -name "*.json" -o -name "*.jsonl" 2>/dev/null | wc -l)
                    echo "   Data files: $data_count found"
                else
                    echo "   ⚠️  No data_files directory"
                fi
                echo ""
                ((count++))
            fi
        fi
    done
}

# Function to validate and fix config file
validate_and_fix_config() {
    local config_file="$1"
    local project_name="$2"
    
    echo "🔧 Validating and fixing config file..."
    
    # Check if config file exists
    if [ ! -f "$config_file" ]; then
        echo "❌ Config file not found: $config_file"
        return 1
    fi
    
    # Test YAML syntax
    cd "$APP_DIR"
    source venv/bin/activate
    
    python3 -c "
import yaml
import sys
import os

try:
    with open('$config_file', 'r') as f:
        config = yaml.safe_load(f)
    print('✅ YAML syntax is valid')
except Exception as e:
    print(f'❌ YAML syntax error: {e}')
    sys.exit(1)

# Check and fix data file paths
data_files = config.get('data_files', [])
fixed_data_files = []
project_data_dir = 'project-hub/$project_name/data_files'

for data_file in data_files:
    # Convert relative paths to project-specific paths
    if not data_file.startswith('/') and not data_file.startswith('project-hub/'):
        # It's a relative path, make it project-specific
        if data_file.startswith('data/'):
            new_path = data_file.replace('data/', f'{project_data_dir}/')
        else:
            new_path = f'{project_data_dir}/{os.path.basename(data_file)}'
        fixed_data_files.append(new_path)
    else:
        fixed_data_files.append(data_file)

# Update the config
config['data_files'] = fixed_data_files
config['output_annotation_dir'] = 'annotation_output/'

# Ensure port is set
if 'port' not in config:
    config['port'] = 5000

# Write the fixed config
with open('config.yaml', 'w') as f:
    yaml.dump(config, f, default_flow_style=False, allow_unicode=True)

print('✅ Config file updated and fixed')

# Verify data files exist
missing_files = []
for data_file in fixed_data_files:
    if not os.path.exists(data_file):
        missing_files.append(data_file)
        print(f'⚠️  Data file not found: {data_file}')
    else:
        print(f'✅ Data file exists: {data_file}')

if missing_files:
    print(f'❌ {len(missing_files)} data files are missing')
    sys.exit(1)
else:
    print('✅ All data files found')

" || return 1

    return 0
}

# Function to create missing data files
create_sample_data() {
    local project_name="$1"
    local data_dir="$APP_DIR/project-hub/$project_name/data_files"
    
    echo "📁 Creating sample data for $project_name..."
    
    mkdir -p "$data_dir"
    
    # Create a sample CSV file
    cat > "$data_dir/sample-data.csv" << 'EOF'
id,text,context
1,"This is a great product! I love it.","Product review"
2,"The service was terrible and slow.","Service feedback"  
3,"Can you help me with my order?","Customer inquiry"
4,"Thank you for the quick response.","Appreciation"
5,"I'm not sure about this feature.","Feature feedback"
6,"The interface is confusing.","UI feedback"
7,"Excellent customer support!","Support review"
8,"How do I cancel my subscription?","Account question"
9,"The delivery was very fast.","Shipping feedback"
10,"I would recommend this to others.","Recommendation"
EOF

    echo "✅ Created sample data file: $data_dir/sample-data.csv"
}

# Function to switch to a specific project config
switch_project() {
    local project_path="$1"
    
    if [ ! -f "$project_path" ]; then
        echo "❌ Config file not found: $project_path"
        exit 1
    fi
    
    local project_name=$(basename "$(dirname "$(dirname "$project_path")")")
    echo "🔄 Switching to project: $project_name"
    echo "Config file: $project_path"
    
    # Backup current config
    if [ -f "$APP_DIR/config.yaml" ]; then
        cp "$APP_DIR/config.yaml" "$APP_DIR/config.yaml.backup.$(date +%Y%m%d_%H%M%S)"
        echo "✅ Backed up current config"
    fi
    
    # Copy new config
    cp "$project_path" "$APP_DIR/config.yaml"
    echo "✅ Copied new config"
    
    # Check if data files exist, create if missing
    local data_dir="$APP_DIR/project-hub/$project_name/data_files"
    if [ ! -d "$data_dir" ] || [ -z "$(ls -A "$data_dir" 2>/dev/null)" ]; then
        echo "⚠️  No data files found for $project_name"
        read -p "Create sample data? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            create_sample_data "$project_name"
        fi
    fi
    
    # Validate and fix the config
    if validate_and_fix_config "$APP_DIR/config.yaml" "$project_name"; then
        echo "✅ Config validation passed"
        
        # Test the config manually first
        echo "🧪 Testing config manually..."
        cd "$APP_DIR"
        source venv/bin/activate
        
        timeout 5s python potato/flask_server.py start config.yaml -p 5000 2>/dev/null || true
        
        # Restart the service
        echo "🔄 Restarting Potato service..."
        sudo systemctl restart potato
        
        sleep 5
        
        if sudo systemctl is-active --quiet potato; then
            echo "✅ Service restarted successfully"
            echo ""
            echo "🎯 New annotation project is now active!"
            echo "🌐 Access it at: http://$(curl -s ifconfig.me 2>/dev/null || echo 'your-droplet-ip')"
            echo ""
            echo "📊 Project details:"
            python3 -c "
import yaml
with open('config.yaml', 'r') as f:
    config = yaml.safe_load(f)
print(f'Task: {config.get(\"annotation_task_name\", \"Unknown\")}')
print(f'Server: {config.get(\"server_name\", \"Unknown\")}')
schemes = config.get('annotation_schemes', [])
if schemes:
    print(f'Annotation type: {schemes[0].get(\"annotation_type\", \"Unknown\")}')
"
        else
            echo "❌ Service failed to start with new config"
            echo "Checking logs:"
            sudo journalctl -u potato -n 10 --no-pager
            
            # Restore backup
            echo "🔄 Restoring previous config..."
            if ls "$APP_DIR"/config.yaml.backup.* 1> /dev/null 2>&1; then
                latest_backup=$(ls -t "$APP_DIR"/config.yaml.backup.* | head -1)
                cp "$latest_backup" "$APP_DIR/config.yaml"
                sudo systemctl restart potato
                echo "✅ Restored previous working config"
            fi
        fi
    else
        echo "❌ Config validation failed, not switching"
        # Restore backup if it exists
        if ls "$APP_DIR"/config.yaml.backup.* 1> /dev/null 2>&1; then
            latest_backup=$(ls -t "$APP_DIR"/config.yaml.backup.* | head -1)
            cp "$latest_backup" "$APP_DIR/config.yaml"
            echo "✅ Restored previous config"
        fi
    fi
}

# Main script logic
cd "$APP_DIR"

if [ $# -eq 0 ]; then
    echo "🥔 Potato Project Switcher (Fixed Version)"
    echo "=========================================="
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