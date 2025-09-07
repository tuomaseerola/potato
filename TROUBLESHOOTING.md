# 🔧 Potato Deployment Troubleshooting

## Quick Fix for Your Current Issue

**Run these commands on your DigitalOcean droplet:**

```bash
# Download and run the fix script
cd /opt/potato
wget https://raw.githubusercontent.com/tuomaseerola/potato/main/fix-digitalocean-service.sh
chmod +x fix-digitalocean-service.sh
./fix-digitalocean-service.sh
```

**Or manually fix the service:**

```bash
# Stop the current service
sudo systemctl stop potato

# Fix the systemd service file
sudo tee /etc/systemd/system/potato.service > /dev/null <<EOF
[Unit]
Description=Potato Annotation Tool
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=/opt/potato
Environment=PATH=/opt/potato/venv/bin
Environment=PYTHONPATH=/opt/potato
ExecStart=/opt/potato/venv/bin/python /opt/potato/potato/flask_server.py start /opt/potato/config.yaml -p 5000
Restart=always
RestartSec=10
StandardOutput=append:/opt/potato/logs/potato.log
StandardError=append:/opt/potato/logs/potato-error.log

[Install]
WantedBy=multi-user.target
EOF

# Reload and start
sudo systemctl daemon-reload
sudo systemctl start potato
sudo systemctl status potato
```

## Common Issues and Solutions

### 1. Service Won't Start (Exit Code 2)

**Symptoms:** Service shows "activating (auto-restart)" with exit code 2

**Causes:**
- Wrong command line arguments
- Missing `--host` flag (not needed)
- Incorrect file paths

**Solution:**
```bash
# Test the command manually
cd /opt/potato
source venv/bin/activate
python potato/flask_server.py start config.yaml -p 5000

# If it works, the systemd service should work too
```

### 2. Permission Denied Errors

**Symptoms:** `PermissionError: [Errno 13] Permission denied`

**Solution:**
```bash
# Fix ownership
sudo chown -R $USER:$USER /opt/potato

# Fix the config file paths
cd /opt/potato
sed -i 's|/app/annotation_output/|annotation_output/|g' config.yaml
```

### 3. Config File Issues

**Symptoms:** YAML parsing errors or file not found

**Solution:**
```bash
# Check if config exists
ls -la /opt/potato/config.yaml

# If missing, copy from template
cd /opt/potato
cp production-config.yaml config.yaml

# Test YAML syntax
python -c "import yaml; yaml.safe_load(open('config.yaml'))"
```

### 4. Port Already in Use

**Symptoms:** `Address already in use` error

**Solution:**
```bash
# Check what's using port 5000
sudo netstat -tlnp | grep :5000

# Kill the process or change port in config.yaml
```

## Diagnostic Commands

### Check Service Status
```bash
sudo systemctl status potato -l
sudo journalctl -u potato -f
```

### Test Manual Startup
```bash
cd /opt/potato
source venv/bin/activate
python potato/flask_server.py start config.yaml -p 5000
```

### Check Dependencies
```bash
cd /opt/potato
source venv/bin/activate
pip list | grep -i flask
python -c "import flask; print('Flask OK')"
```

### Check File Permissions
```bash
ls -la /opt/potato/
ls -la /opt/potato/config.yaml
ls -la /opt/potato/potato/flask_server.py
```

## Fresh Installation

If all else fails, start fresh:

```bash
# Remove old installation
sudo systemctl stop potato || true
sudo systemctl disable potato || true
sudo rm -rf /opt/potato
sudo rm /etc/systemd/system/potato.service

# Run the fixed deployment script
git clone https://github.com/tuomaseerola/potato.git /tmp/potato-deploy
cd /tmp/potato-deploy
chmod +x digitalocean-deploy-fixed.sh
./digitalocean-deploy-fixed.sh
```

## Verification Steps

After fixing, verify everything works:

```bash
# 1. Service is running
sudo systemctl status potato

# 2. Port is listening
sudo netstat -tlnp | grep :5000

# 3. Nginx is proxying
curl -I http://localhost

# 4. External access works
curl -I http://your-droplet-ip
```

## Getting Help

If you're still having issues:

1. **Check the logs:**
   ```bash
   sudo journalctl -u potato -n 50 --no-pager
   ```

2. **Test manually:**
   ```bash
   cd /opt/potato
   source venv/bin/activate
   python potato/flask_server.py start config.yaml -p 5000
   ```

3. **Share the error output** - Copy the exact error messages for further assistance.

## Success Indicators

You'll know it's working when:
- ✅ `sudo systemctl status potato` shows "active (running)"
- ✅ You can access `http://your-droplet-ip` in a browser
- ✅ The annotation interface loads
- ✅ You can submit test annotations