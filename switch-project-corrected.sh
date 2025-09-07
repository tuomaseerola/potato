#!/bin/bash

# CORRECTED script to switch between different Potato annotation projects
# Fixes the missing /configs/ folder issue
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
            configs_dir="$project_dir/configs"
            
            if [ "$project_name" != "*.zip" ] && [ -d "$configs_dir" ]; then
                echo "$count. $project_name"
                
                # List config files in this project
                echo "   Config files:"
                find "$configs_dir" -name "*.yaml" -o -name "*.yml" 2>/dev/null | while read config; do
                    echo "   - $(basename "$config")"
                done
                
                # Check if data files exist
                data_dir="$project_dir/data_files"
                if [ -d "$data_dir" ]; then
                    data_count=$(find "$data_dir" -name "*.csv" -o -name "*.json" -o -name "*.jsonl" 2>/dev/null | wc -l)
                    echo "   Data files: $data_count found"
                    
                    # Show first few data files
                    find "$data_dir" -name "*.csv" -o -name "*.json" -o -name "*.jsonl" 2>/dev/null | head -3 | while read data_file; do
                        echo "     - $(basename "$data_file")"
                    done
                else
                    echo "   ⚠️  No data_files directory"
                fi
                echo ""
                ((count++))
            fi
        fi
    done
    
    echo "Usage examples:"
    echo "  $0 sentiment_analysis/sentiment-analysis.yaml"
    echo "  $0 empathy/empathy.yaml"
    echo "  $0 simple_examples/simple-check-box.yaml"
}

# Function to create missing data files
create_sample_data() {
    local project_name="$1"
    local data_dir="$APP_DIR/project-hub/$project_name/data_files"
    
    echo "📁 Creating sample data for $project_name..."
    
    mkdir -p "$data_dir"
    
    # Create different sample data based on project type
    case $project_name in
        "sentiment_analysis")
            cat > "$data_dir/sentiment-data.csv" << 'EOF'
id,text,context
1,"I absolutely love this product! It's amazing!","Product review"
2,"This is the worst service I've ever experienced.","Service feedback"
3,"The movie was okay, nothing special.","Movie review"
4,"Fantastic customer support, very helpful!","Support review"
5,"I'm not sure how I feel about this feature.","Feature feedback"
6,"Terrible quality, would not recommend.","Product review"
7,"Great value for money, highly satisfied.","Purchase review"
8,"The interface is confusing and hard to use.","UI feedback"
9,"Outstanding performance, exceeded expectations!","Performance review"
10,"Average product, meets basic requirements.","Product review"
EOF
            ;;
        "empathy")
            cat > "$data_dir/empathy-data.csv" << 'EOF'
id,text,context
1,"I understand how difficult this must be for you.","Supportive response"
2,"That sounds really challenging to deal with.","Empathetic response"
3,"You should just get over it and move on.","Dismissive response"
4,"I can imagine how frustrated you must feel.","Understanding response"
5,"Have you tried not being so sensitive?","Insensitive response"
6,"It's completely normal to feel that way.","Validating response"
7,"I've been through something similar myself.","Shared experience"
8,"That's not really a big deal, honestly.","Minimizing response"
9,"Your feelings are completely valid here.","Supportive response"
10,"I'm here if you need someone to talk to.","Caring response"
EOF
            ;;
        *)
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
            ;;
    esac
    
    echo "✅ Created sample data file in $data_dir"
}

# Function to validate and fix config file
validate_and_fix_config() {
    local project_name="$1"
    
    echo "🔧 Validating and fixing config file..."
    
    cd "$APP_DIR"
    source venv/bin/activate
    
    python3 -c "
import yaml
import sys
import os

try:
    with open('config.yaml', 'r') as f:
        config = yaml.safe_load(f)
    print('✅ YAML syntax is valid')
except Exception as e:
    print(f'❌ YAML syntax error: {e}')
    sys.exit(1)

# Check and fix data file paths
data_files = config.get('data_files', [])
fixed_data_files = []
project_data_dir = f'project-hub/$project_name/data_files'

print(f'Original data files: {data_files}')

for data_file in data_files:
    # Convert relative paths to project-specific paths
    if not data_file.startswith('/') and not data_file.startswith('project-hub/'):
        # It's a relative path, make it project-specific
        if data_file.startswith('data_files/') or data_file.startswith('data/'):
            # Remove the prefix and use just the filename
            filename = os.path.basename(data_file)
            new_path = f'{project_data_dir}/{filename}'
        else:
            new_path = f'{project_data_dir}/{os.path.basename(data_file)}'
        fixed_data_files.append(new_path)
        print(f'Fixed path: {data_file} -> {new_path}')
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
print(f'Fixed data files: {fixed_data_files}')

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
    # Don't exit, we'll create them
    for missing_file in missing_files:
        print(f'Will need to create: {missing_file}')
else:
    print('✅ All data files found')

" || return 1

    return 0
}

# Function to switch to a specific project config
switch_project() {
    local project_config="$1"
    
    # Parse the project path correctly
    # Expected format: project_name/config_file.yaml
    local project_name=$(echo "$project_config" | cut -d'/' -f1)
    local config_file=$(echo "$project_config" | cut -d'/' -f2)
    
    # Build the full path to the config file
    local full_config_path="$APP_DIR/project-hub/$project_name/configs/$config_file"
    
    echo "🔄 Switching to project: $project_name"
    echo "Config file: $config_file"
    echo "Full path: $full_config_path"
    
    if [ ! -f "$full_config_path" ]; then
        echo "❌ Config file not found: $full_config_path"
        echo ""
        echo "Available configs for $project_name:"
        if [ -d "$APP_DIR/project-hub/$project_name/configs" ]; then
            ls -la "$APP_DIR/project-hub/$project_name/configs/"
        else
            echo "❌ No configs directory found for $project_name"
        fi
        exit 1
    fi
    
    # Backup current config
    if [ -f "$APP_DIR/config.yaml" ]; then
        cp "$APP_DIR/config.yaml" "$APP_DIR/config.yaml.backup.$(date +%Y%m%d_%H%M%S)"
        echo "✅ Backed up current config"
    fi
    
    # Copy new config
    cp "$full_config_path" "$APP_DIR/config.yaml"
    echo "✅ Copied new config"
    
    # Check if data files exist, create if missing
    local data_dir="$APP_DIR/project-hub/$project_name/data_files"
    if [ ! -d "$data_dir" ] || [ -z "$(ls -A "$data_dir" 2>/dev/null)" ]; then
        echo "⚠️  No data files found for $project_name"
        echo "Creating sample data..."
        create_sample_data "$project_name"
    fi
    
    # Validate and fix the config
    if validate_and_fix_config "$project_name"; then
        echo "✅ Config validation passed"
        
        # Test the config manually first
        echo "🧪 Testing config manually..."
        cd "$APP_DIR"
        source venv/bin/activate
        
        echo "Running: timeout 5s python potato/flask_server.py start config.yaml -p 5000"
        timeout 5s python potato/flask_server.py start config.yaml -p 5000 2>&1 | head -10 || echo "Manual test completed"
        
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
    labels = schemes[0].get('labels', [])
    if labels:
        print(f'Labels: {labels[:5]}' + ('...' if len(labels) > 5 else ''))
"
        else
            echo "❌ Service failed to start with new config"
            echo "Checking logs:"
            sudo journalctl -u potato -n 15 --no-pager
            
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
    echo "🥔 Potato Project Switcher (CORRECTED Version)"
    echo "=============================================="
    echo ""
    echo "This version correctly handles the /configs/ folder structure!"
    echo ""
    list_projects
    
elif [ "$1" = "list" ]; then
    list_projects
    
else
    switch_project "$1"
fi
EOF