# 🔧 Potato Annotation Saving Troubleshooting Guide

## 🚨 **Quick Fix - Run This First**

**On your DigitalOcean droplet:**

```bash
cd /opt/potato
chmod +x fix-annotation-saving.sh
./fix-annotation-saving.sh
```

## 🔍 **Detailed Diagnosis**

**Run the diagnostic script:**

```bash
cd /opt/potato
chmod +x diagnose-annotations.sh
./diagnose-annotations.sh
```

## 🎯 **Common Issues & Solutions**

### 1. **Directory Doesn't Exist**
```bash
# Check if directory exists
ls -la /opt/potato/annotation_output/

# If missing, create it:
mkdir -p /opt/potato/annotation_output
chown $USER:$USER /opt/potato/annotation_output
```

### 2. **Permission Issues**
```bash
# Fix ownership
sudo chown -R $USER:$USER /opt/potato

# Check service user matches
grep "User=" /etc/systemd/system/potato.service
whoami
```

### 3. **Configuration Problems**
```bash
# Check config
grep "output_annotation" /opt/potato/config.yaml

# Should show:
# "output_annotation_dir": "annotation_output/",
# "output_annotation_format": "jsonl",
```

### 4. **Annotations Not Triggering Save**
The app only saves when you **actually submit** an annotation. Make sure you:

1. **Select at least one category** (positive, negative, etc.)
2. **Click the Submit button** (not just Next)
3. **Wait for the page to reload** before checking files

## 🧪 **Testing Steps**

### Step 1: Access Your Tool
```bash
# Get your droplet IP
curl ifconfig.me
```
Then go to: `http://your-droplet-ip`

### Step 2: Submit Test Annotation
1. Select one or more categories
2. Click "Submit" button
3. Wait for page to reload

### Step 3: Check for Files
```bash
# Monitor in real-time
watch -n 1 'ls -la /opt/potato/annotation_output/'

# Or check once
ls -la /opt/potato/annotation_output/
```

### Step 4: View Saved Data
```bash
# View the annotation file
cat /opt/potato/annotation_output/annotated_instances.jsonl

# Pretty print JSON
python3 -m json.tool /opt/potato/annotation_output/annotated_instances.jsonl
```

## 📊 **Expected File Structure**

After successful annotations, you should see:
```
/opt/potato/annotation_output/
├── annotated_instances.jsonl          # Main annotation file
├── anonymous_user/                    # User-specific folder
│   ├── annotation_state.json         # User's annotation state
│   └── behavioral_data.json          # Timing/behavior data
└── user_config.json                  # User configuration
```

## 📝 **Sample Annotation Data**

Each line in `annotated_instances.jsonl` looks like:
```json
{
  "user_id": "anonymous_user",
  "instance_id": "1",
  "displayed_text": "This is a great product! I love it.",
  "label_annotations": {
    "categories": {
      "positive": true,
      "negative": false,
      "neutral": false,
      "question": false,
      "request": false,
      "complaint": false
    }
  },
  "span_annotations": [],
  "behavioral_data": {
    "time_spent": 12.5,
    "timestamp": "2024-01-01T12:00:00Z"
  }
}
```

## 🔄 **If Still Not Working**

### Check Logs:
```bash
# Service logs
sudo journalctl -u potato -f

# Application logs
tail -f /opt/potato/logs/potato.log
```

### Manual Test:
```bash
cd /opt/potato
source venv/bin/activate
python potato/flask_server.py start config.yaml -p 5000
# Then test in browser at http://your-ip:5000
```

### Restart Everything:
```bash
sudo systemctl restart potato
sudo systemctl restart nginx
```

## 🆘 **Still Having Issues?**

### Debug Mode:
```bash
# Stop service
sudo systemctl stop potato

# Run manually with debug
cd /opt/potato
source venv/bin/activate
python potato/flask_server.py start config.yaml -p 5000 --debug

# Test annotation, then check console output
```

### Check Flask Server Code:
The saving happens in the `save_all_annotations()` function, which is called after `update_annotation_state()` returns `True`. This means:

1. You must actually change something (select categories)
2. You must submit the form (not just navigate)
3. The form data must be processed successfully

### Verify Form Submission:
- Open browser developer tools (F12)
- Go to Network tab
- Submit an annotation
- Look for POST request to `/` with form data

## ✅ **Success Indicators**

You'll know it's working when:
- ✅ Files appear in `/opt/potato/annotation_output/`
- ✅ `annotated_instances.jsonl` contains your annotations
- ✅ File timestamps update after each submission
- ✅ User folders are created for each annotator

## 📞 **Get Help**

If none of this works, share:
1. Output of `diagnose-annotations.sh`
2. Service logs: `sudo journalctl -u potato -n 50`
3. Directory listing: `ls -la /opt/potato/annotation_output/`
4. Config check: `grep output /opt/potato/config.yaml`