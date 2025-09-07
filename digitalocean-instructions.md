# Deploy Potato Annotation Tool to DigitalOcean Droplet

## Prerequisites
- DigitalOcean droplet running Ubuntu 20.04+ or Debian 10+
- SSH access to your droplet
- At least 1GB RAM and 10GB storage

## Quick Deployment

### Step 1: Connect to Your Droplet
```bash
ssh root@your-droplet-ip
# or
ssh your-username@your-droplet-ip
```

### Step 2: Download and Run Deployment Script
```bash
# Download the repository
git clone https://github.com/tuomaseerola/potato.git
cd potato

# Make deployment script executable
chmod +x digitalocean-deploy.sh

# Run the deployment script
./digitalocean-deploy.sh
```

The script will automatically:
- Install all required dependencies (Python, Nginx, etc.)
- Set up the Potato application in `/opt/potato/`
- Configure Nginx as a reverse proxy
- Create systemd service for auto-start
- Set up firewall rules
- Create daily backup cron job

### Step 3: Access Your Application
After deployment completes, access your annotation tool at:
- `http://your-droplet-ip`

## Manual Deployment (Alternative)

If you prefer manual setup:

### 1. System Setup
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y python3 python3-pip python3-venv git nginx
```

### 2. Application Setup
```bash
# Create app directory
sudo mkdir -p /opt/potato
sudo chown $USER:$USER /opt/potato

# Clone repository
git clone https://github.com/tuomaseerola/potato.git /opt/potato
cd /opt/potato

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install Python packages
pip install -r requirements.txt

# Create directories
mkdir -p annotation_output logs
```

### 3. Configuration
```bash
# Copy production config
cp production-config.yaml config.yaml

# Edit config if needed
nano config.yaml
```

### 4. Service Setup
Create systemd service file:
```bash
sudo nano /etc/systemd/system/potato.service
```

Add the service configuration (see deployment script for content).

### 5. Nginx Setup
```bash
# Create nginx config
sudo nano /etc/nginx/sites-available/potato

# Enable site
sudo ln -s /etc/nginx/sites-available/potato /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default

# Test and restart
sudo nginx -t
sudo systemctl restart nginx
```

### 6. Start Services
```bash
sudo systemctl daemon-reload
sudo systemctl enable potato
sudo systemctl start potato
sudo systemctl enable nginx
```

## Configuration Options

### Custom Data
To use your own data:
1. Upload CSV/JSON files to `/opt/potato/data/`
2. Edit `/opt/potato/config.yaml` to reference your data files
3. Restart the service: `sudo systemctl restart potato`

### Annotation Schemes
Modify the `annotation_schemes` section in `config.yaml` to customize:
- Label types and options
- Annotation interfaces (radio, checkbox, text, etc.)
- Keyboard shortcuts

### User Access Control
To restrict access:
1. Set `"allow_all_users": false` in config.yaml
2. Add specific users to the `"users"` array
3. Restart the service

## Data Management

### Accessing Annotations
Annotations are saved in `/opt/potato/annotation_output/` in JSONL format.

### Backup Data
```bash
# Manual backup
/opt/potato/backup-annotations.sh

# View backups
ls -la /opt/potato-backups/
```

### Download Annotations
```bash
# From your local machine
scp your-username@your-droplet-ip:/opt/potato/annotation_output/* ./local-folder/
```

## Monitoring and Maintenance

### View Logs
```bash
# Application logs
sudo journalctl -u potato -f

# Nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

### Service Management
```bash
# Check status
sudo systemctl status potato

# Restart application
sudo systemctl restart potato

# Stop/start
sudo systemctl stop potato
sudo systemctl start potato
```

### Updates
```bash
cd /opt/potato
git pull origin main
source venv/bin/activate
pip install -r requirements.txt
sudo systemctl restart potato
```

## Security Considerations

### SSL/HTTPS (Recommended)
To add SSL certificate:
```bash
# Install certbot
sudo apt install certbot python3-certbot-nginx

# Get certificate (replace with your domain)
sudo certbot --nginx -d your-domain.com

# Auto-renewal is set up automatically
```

### Firewall
The deployment script configures UFW firewall. To modify:
```bash
# Check status
sudo ufw status

# Allow additional ports if needed
sudo ufw allow 443/tcp  # HTTPS
```

## Troubleshooting

### Common Issues

1. **Service won't start**
   ```bash
   sudo journalctl -u potato -n 50
   ```

2. **Nginx errors**
   ```bash
   sudo nginx -t
   sudo systemctl status nginx
   ```

3. **Permission issues**
   ```bash
   sudo chown -R $USER:$USER /opt/potato
   ```

4. **Port conflicts**
   ```bash
   sudo netstat -tlnp | grep :5000
   ```

### Getting Help
- Check logs: `sudo journalctl -u potato -f`
- Verify config: `cd /opt/potato && python -c "import yaml; yaml.safe_load(open('config.yaml'))"`
- Test manually: `cd /opt/potato && source venv/bin/activate && python potato/flask_server.py start config.yaml -p 5000`

## Cost Optimization

For a basic annotation tool, a $6/month DigitalOcean droplet (1GB RAM, 1 vCPU) should be sufficient for small teams. Scale up as needed based on usage.