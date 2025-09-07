#!/bin/bash

# Emergency fix to get Potato service running immediately
# Run this on your DigitalOcean droplet

set -e

APP_DIR="/opt/potato"
cd $APP_DIR

echo "🚨 Emergency fix for Potato service..."
echo "===================================="

echo ""
echo "🔄 1. Stopping failed service:"
echo "------------------------------"
sudo systemctl stop potato || true

echo ""
echo "📋 2. Creating working config:"
echo "-----------------------------"

# Create a guaranteed working config
cat > config.yaml << 'EOF'
{
    "port": 5000,
    "server_name": "Potato Annotation Tool",
    "annotation_task_name": "Text Annotation",
    "output_annotation_dir": "annotation_output/",
    "output_annotation_format": "jsonl", 
    "annotation_codebook_url": "",
    "data_files": [
       "emergency_data/sample.csv"
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

echo "✅ Created emergency config"

echo ""
echo "📁 3. Creating emergency data:"
echo "-----------------------------"
mkdir -p emergency_data

cat > emergency_data/sample.csv << 'EOF'
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

echo "✅ Created emergency data file"

echo ""
echo "🧪 4. Testing config:"
echo "--------------------"
source venv/bin/activate
python3 -c "
import yaml
import os
try:
    with open('config.yaml', 'r') as f:
        config = yaml.safe_load(f)
    print('✅ Config syntax valid')
    
    data_files = config.get('data_files', [])
    for data_file in data_files:
        if os.path.exists(data_file):
            print(f'✅ Data file exists: {data_file}')
        else:
            print(f'❌ Data file missing: {data_file}')
            exit(1)
    print('✅ All data files found')
except Exception as e:
    print(f'❌ Error: {e}')
    exit(1)
"

if [ $? -eq 0 ]; then
    echo ""
    echo "🚀 5. Starting service:"
    echo "----------------------"
    sudo systemctl start potato
    
    sleep 5
    
    if sudo systemctl is-active --quiet potato; then
        echo "✅ SERVICE IS NOW RUNNING!"
        echo ""
        echo "🌐 Access your annotation tool at:"
        echo "   http://$(curl -s ifconfig.me 2>/dev/null || echo 'your-droplet-ip')"
        echo ""
        echo "📊 Service status:"
        sudo systemctl status potato --no-pager -l | head -5
    else
        echo "❌ Service still not starting"
        echo "Logs:"
        sudo journalctl -u potato -n 10 --no-pager
    fi
else
    echo "❌ Config test failed"
fi

echo ""
echo "Emergency fix complete! 🏁"
EOF