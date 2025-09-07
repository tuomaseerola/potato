# Potato Annotation Tool - Deployment Instructions

This repository is ready to deploy the Potato annotation tool to various cloud platforms with persistent data storage.

## Quick Deploy Options

### Option 1: Railway (Recommended - Easiest)

1. Fork this repository to your GitHub account
2. Go to [Railway.app](https://railway.app)
3. Sign up/login with GitHub
4. Click "New Project" → "Deploy from GitHub repo"
5. Select your forked repository
6. Railway will automatically detect the `railway.json` and deploy
7. Your app will be available at the provided Railway URL

**Data Persistence**: Railway automatically provides persistent storage for the `/app/annotation_output/` directory.

### Option 2: Render

1. Fork this repository to your GitHub account
2. Go to [Render.com](https://render.com)
3. Sign up/login with GitHub
4. Click "New" → "Web Service"
5. Connect your forked repository
6. Render will detect the `render.yaml` configuration
7. Deploy and access via the provided Render URL

**Data Persistence**: Render provides a 1GB persistent disk mounted at `/app/annotation_output/`.

### Option 3: Fly.io

1. Install the Fly CLI: `curl -L https://fly.io/install.sh | sh`
2. Fork and clone this repository
3. Run `fly auth login`
4. Run `fly launch` (it will detect the `fly.toml`)
5. Create a volume: `fly volumes create potato_data --size 1`
6. Deploy: `fly deploy`

**Data Persistence**: Uses Fly volumes for persistent storage.

## Configuration

### Default Setup
The deployment includes a sample configuration that allows:
- Multi-select annotation with categories: positive, negative, neutral, question, request, complaint
- File-based data storage (JSON Lines format)
- Open access (no user authentication required)

### Custom Configuration
To customize your annotation task:

1. Edit `production-config.yaml` to modify:
   - Annotation schemes and labels
   - Data file paths
   - Output formats
   - User access controls

2. Upload your own data files to the `data/` directory

3. Redeploy to apply changes

## Data Management

### Accessing Annotations
Annotations are saved to `/app/annotation_output/` in the specified format (default: JSONL).

For Railway/Render: Use their dashboard to access files or set up automated backups.

### Data Format
Annotations are saved in JSON Lines format with structure:
```json
{
  "id": "instance_id",
  "text": "original_text", 
  "annotations": {
    "categories": ["positive", "request"]
  },
  "annotator": "user_id",
  "timestamp": "2024-01-01T12:00:00Z"
}
```

## Security Notes

- The default configuration allows open access
- For production use, configure user authentication in the YAML file
- Consider adding environment variables for sensitive configuration
- Set up regular backups of annotation data

## Troubleshooting

### Common Issues:
1. **Port conflicts**: The app runs on port 8000 internally
2. **Data not persisting**: Ensure the platform supports persistent volumes
3. **Configuration errors**: Check YAML syntax in config files

### Logs:
- Railway: View logs in the Railway dashboard
- Render: Check logs in the Render dashboard  
- Fly.io: Use `fly logs` command

## Support

For Potato-specific issues, refer to the [official documentation](https://potato-annotation.readthedocs.io/) or the [GitHub repository](https://github.com/tuomaseerola/potato).