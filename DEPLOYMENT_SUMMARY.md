# 🥔 Potato Annotation Tool - DigitalOcean Deployment Summary

## ✅ What's Ready

Your Potato annotation tool is fully configured and ready to deploy to your DigitalOcean droplet. All necessary files have been created:

### Deployment Files Created:
- `digitalocean-deploy.sh` - Automated deployment script
- `digitalocean-instructions.md` - Detailed deployment guide
- `production-config.yaml` - Production-ready configuration
- `Dockerfile` - Container configuration
- `docker-compose.yml` - Multi-container setup
- `nginx.conf` - Reverse proxy configuration

## 🚀 Quick Deployment Steps

### Option 1: Automated Script (Recommended)
```bash
# On your DigitalOcean droplet:
git clone https://github.com/tuomaseerola/potato.git
cd potato
chmod +x digitalocean-deploy.sh
./digitalocean-deploy.sh
```

### Option 2: Docker Compose
```bash
# On your DigitalOcean droplet:
git clone https://github.com/tuomaseerola/potato.git
cd potato
docker-compose up -d
```

## 📊 What You Get

### Features Included:
- ✅ **Multi-select annotation interface** - Users can select multiple categories
- ✅ **File-based data persistence** - Annotations saved as JSONL files
- ✅ **Nginx reverse proxy** - Professional web server setup
- ✅ **Automatic backups** - Daily cron job for data safety
- ✅ **Systemd service** - Auto-restart and system integration
- ✅ **Firewall configuration** - Basic security setup
- ✅ **SSL-ready** - Easy HTTPS setup with Let's Encrypt

### Default Annotation Categories:
- Positive
- Negative  
- Neutral
- Question
- Request
- Complaint

## 💾 Data Management

### Data Storage:
- **Location**: `/opt/potato/annotation_output/`
- **Format**: JSON Lines (.jsonl)
- **Backups**: `/opt/potato-backups/` (daily automated)

### Sample Annotation Output:
```json
{
  "id": "1",
  "text": "This is a great product!",
  "annotations": {
    "sentiment": ["positive"]
  },
  "annotator": "user123",
  "timestamp": "2024-01-01T12:00:00Z"
}
```

## 🔧 Customization

### Add Your Own Data:
1. Upload CSV/JSON files to `/opt/potato/data/`
2. Edit `/opt/potato/config.yaml` to reference your files
3. Restart: `sudo systemctl restart potato`

### Modify Annotation Schemes:
Edit the `annotation_schemes` section in `config.yaml` to change:
- Label options
- Interface types (radio, checkbox, text, etc.)
- Descriptions and instructions

### Example Custom Scheme:
```yaml
annotation_schemes:
  - annotation_type: "radio"
    name: "emotion"
    description: "What emotion is expressed?"
    labels: ["joy", "anger", "sadness", "fear", "surprise"]
    sequential_key_binding: true
```

## 🌐 Access Control

### Open Access (Default):
```yaml
user_config:
  allow_all_users: true
  users: []
```

### Restricted Access:
```yaml
user_config:
  allow_all_users: false
  users: ["annotator1", "annotator2", "researcher"]
```

## 📈 Monitoring

### Check Status:
```bash
sudo systemctl status potato
sudo journalctl -u potato -f
```

### View Annotations:
```bash
ls -la /opt/potato/annotation_output/
cat /opt/potato/annotation_output/annotated_instances.jsonl
```

### Download Data:
```bash
# From your local machine:
scp user@your-droplet-ip:/opt/potato/annotation_output/* ./local-folder/
```

## 💰 Cost Estimate

For a basic annotation tool:
- **DigitalOcean Droplet**: $6/month (1GB RAM, 1 vCPU)
- **Storage**: Included (25GB SSD)
- **Bandwidth**: 1TB included

Scale up based on usage:
- More annotators → More RAM/CPU
- Large datasets → More storage
- High traffic → Load balancer

## 🔒 Security Recommendations

1. **Enable SSL**: Use Let's Encrypt for HTTPS
2. **Regular backups**: Automated daily backups included
3. **User authentication**: Configure user access controls
4. **Firewall**: UFW configured for ports 22, 80, 443
5. **Updates**: Regular system and application updates

## 📞 Support

### Troubleshooting:
- Check logs: `sudo journalctl -u potato -f`
- Restart service: `sudo systemctl restart potato`
- Test config: `cd /opt/potato && python -c "import yaml; yaml.safe_load(open('config.yaml'))"`

### Resources:
- [Potato Documentation](https://potato-annotation.readthedocs.io/)
- [GitHub Repository](https://github.com/tuomaseerola/potato)
- Deployment files in this repository

## 🎯 Next Steps

1. **Deploy to your DigitalOcean droplet** using the provided scripts
2. **Upload your data** to replace the sample data
3. **Customize annotation schemes** for your specific needs
4. **Share the URL** with your annotators
5. **Monitor and download** annotations as they come in

Your annotation tool will be accessible at `http://your-droplet-ip` after deployment!