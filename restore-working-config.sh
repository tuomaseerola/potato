#!/bin/bash

# Quick script to restore a working configuration
# Run this on your DigitalOcean droplet

set -e

APP_DIR="/opt/potato"
cd $APP_DIR

echo "🔄 Restoring working Potato configuration..."
echo "==========================================="

echo ""
echo "📋 1. Looking for backup configs:"
echo "--------------------------------"
ls -la config.yaml.backup.* 2>/dev/null || echo "No backup configs found"

echo ""
echo "📄 2. Using production config as fallback:"
echo "-----------------------------------------"
if [ -f "production-config.yaml" ]; then
    echo "✅ Found production-config.yaml"
    
    # Copy production config
    cp production-config.yaml config.yaml
    echo "✅ Copied production config to config.yaml"
    
    # Fix any path issues
    sed -i 's|/app/annotation_output/|annotation_output/|g' config.yaml
    echo "✅ Fixed output directory path"
    
    # Ensure data files exist
    if [ ! -f "project-hub/simple_examples/data/toy-example.csv" ]; then
        echo "⚠️  Creating missing data directory..."
        mkdir -p project-hub/simple_examples/data
        
        # Create a simple test data file
        cat > project-hub/simple_examples/data/toy-example.csv << 'EOF'
id,text,context
1,"This is a great product! I love it.","Product review"
2,"The service was terrible and slow.","Service feedback"
3,"Can you help me with my order?","Customer inquiry"
4,"Thank you for the quick response.","Appreciation"
5,"I'm not sure about this feature.","Feature feedback"
EOF
        echo "✅ Created test data file"
    fi
    
    # Update data file path in config
    sed -i 's|project-hub/simple_examples/data/toy-example.csv|project-hub/simple_examples/data/toy-example.csv|g' config.yaml
    
else
    echo "❌ No production-config.yaml found"
    echo "Creating basic config..."
    
    # Create a minimal working config
    cat > config.yaml << 'EOF'
{
    "port": 5000,
    "server_name": "Potato Annotation Tool",
    "annotation_task_name": "Basic Text Annotation",
    "output_annotation_dir": "annotation_output/",
    "output_annotation_format": "jsonl", 
    "annotation_codebook_url": "",
    "data_files": [
       "test_data/sample.csv"
    ],
    "item_properties": {
        "id_key": "id",
        "text_key": "text",
        "context_key": "context"
    },
    "user_config": {
      "allow_all_users": true,
      "users": []
    },
    "alert_time_each_instance": 300,
    "annotation_schemes": [      
        {
            "annotation_type": "multiselect",
            "name": "categories", 
            "description": "What categories apply to this text?",
            "labels": [
               "positive", "negative", "neutral", "question", "request", "complaint"
            ],
            "sequential_key_binding": true            
        }       
    ],
    "html_layout": "default",
    "base_html_template": "default",
    "header_file": "default",
    "site_dir": "default"
}
EOF
    
    # Ensure test data exists
    mkdir -p test_data
    if [ ! -f "test_data/sample.csv" ]; then
        cat > test_data/sample.csv << 'EOF'
id,text,context
1,"This is a great product! I love it.","Product review"
2,"The service was terrible and slow.","Service feedback"
3,"Can you help me with my order?","Customer inquiry"
4,"Thank you for the quick response.","Appreciation"
5,"I'm not sure about this feature.","Feature feedback"
EOF
    fi
    
    echo "✅ Created basic working config"
fi

echo ""
echo "🧪 3. Testing configuration:"
echo "---------------------------"
source venv/bin/activate
python3 -c "
import yaml
try:
    with open('config.yaml', 'r') as f:
        config = yaml.safe_load(f)
    print('✅ Config syntax is valid')
    
    # Check data files
    import os
    data_files = config.get('data_files', [])
    for data_file in data_files:
        if os.path.exists(data_file):
            print(f'✅ Data file exists: {data_file}')
        else:
            print(f'❌ Data file missing: {data_file}')
            
except Exception as e:
    print(f'❌ Config error: {e}')
    exit(1)
"

if [ $? -eq 0 ]; then
    echo ""
    echo "🔄 4. Restarting service:"
    echo "------------------------"
    sudo systemctl restart potato
    
    sleep 3
    
    if sudo systemctl is-active --quiet potato; then
        echo "✅ Service started successfully!"
        echo ""
        echo "🌐 Your annotation tool should now be accessible at:"
        echo "   http://$(curl -s ifconfig.me 2>/dev/null || echo 'your-droplet-ip')"
        echo ""
        echo "📊 Service status:"
        sudo systemctl status potato --no-pager -l | head -5
    else
        echo "❌ Service still failing to start"
        echo "Recent logs:"
        sudo journalctl -u potato -n 10 --no-pager
    fi
else
    echo "❌ Config still has errors, not restarting service"
fi

echo ""
echo "Restore complete! 🏁"
EOF