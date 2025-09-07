# 🥔 Potato Project Switching Guide

Switch between different annotation projects easily! You have multiple options depending on your needs.

## 🎯 **Available Annotation Projects**

Your project-hub contains these annotation types:
- **Sentiment Analysis** - Classify text sentiment (positive/negative/neutral)
- **Empathy Detection** - Measure empathy levels in text
- **Dialogue Analysis** - Analyze conversational patterns
- **Question Answering** - QA annotation tasks
- **Text Rewriting** - Text improvement annotations
- **Span Labeling** - Highlight specific text spans
- **And many more!**

## 🚀 **Option 1: Simple Project Switching (Recommended)**

**Switch between projects on the same service:**

```bash
cd /opt/potato

# List all available projects
./switch-project.sh list

# Switch to sentiment analysis
./switch-project.sh sentiment_analysis/sentiment-analysis.yaml

# Switch to empathy detection
./switch-project.sh empathy/empathy.yaml

# Switch to simple checkbox example
./switch-project.sh simple_examples/simple-check-box.yaml
```

**What this does:**
- ✅ Backs up your current config
- ✅ Copies the new project config
- ✅ Updates file paths automatically
- ✅ Restarts the service
- ✅ Validates the configuration

## 🌐 **Option 2: Web-Based Project Manager**

**Start the web interface:**

```bash
cd /opt/potato
python3 project-manager.py
```

Then visit: `http://your-droplet-ip:8080`

**Features:**
- 🖱️ Click to switch projects
- 📊 View service status
- 📝 Check logs
- 🔄 Start/stop services
- 📋 See all available projects

## ⚡ **Option 3: Multiple Projects Simultaneously**

**Run different projects on different URLs:**

```bash
cd /opt/potato
./setup-multi-project.sh
```

**Result:**
- `http://your-droplet-ip/sentiment/` - Sentiment Analysis
- `http://your-droplet-ip/empathy/` - Empathy Detection  
- `http://your-droplet-ip/simple/` - Simple Examples
- `http://your-droplet-ip/` - Project selection page

**Each project:**
- ✅ Runs on separate port
- ✅ Has separate data storage
- ✅ Can be managed independently
- ✅ Accessible via different URLs

## 📋 **Available Project Types**

### **1. Sentiment Analysis**
```bash
./switch-project.sh sentiment_analysis/sentiment-analysis.yaml
```
- **Type:** Radio buttons (positive/negative/neutral)
- **Use case:** Social media analysis, review classification
- **Data format:** Text with sentiment labels

### **2. Empathy Detection**
```bash
./switch-project.sh empathy/empathy.yaml
```
- **Type:** Likert scale rating
- **Use case:** Psychological research, conversation analysis
- **Data format:** Text with empathy ratings

### **3. Simple Examples**
```bash
./switch-project.sh simple_examples/simple-check-box.yaml
```
- **Type:** Multi-select checkboxes
- **Use case:** Learning, testing, multi-label classification
- **Data format:** Text with multiple category labels

### **4. Span Labeling**
```bash
./switch-project.sh simple_examples/simple-span-labeling.yaml
```
- **Type:** Text highlighting
- **Use case:** Named entity recognition, text annotation
- **Data format:** Text with highlighted spans

### **5. Question Answering**
```bash
./switch-project.sh question_answering/question-answering.yaml
```
- **Type:** Text input fields
- **Use case:** Reading comprehension, QA datasets
- **Data format:** Questions with answer annotations

## 🔧 **Custom Project Setup**

**Create your own project:**

1. **Copy an existing project:**
   ```bash
   cp -r project-hub/simple_examples project-hub/my-project
   ```

2. **Edit the config file:**
   ```bash
   nano project-hub/my-project/configs/my-config.yaml
   ```

3. **Update your data:**
   ```bash
   # Add your CSV/JSON data files to:
   project-hub/my-project/data_files/
   ```

4. **Switch to your project:**
   ```bash
   ./switch-project.sh my-project/my-config.yaml
   ```

## 📁 **Data Storage Locations**

### **Single Project Mode:**
```
/app/annotation_output/
├── annotated_instances.jsonl
└── user_folders/
```

### **Multi-Project Mode:**
```
/opt/potato/annotation_output/
├── sentiment/
│   └── annotated_instances.jsonl
├── empathy/
│   └── annotated_instances.jsonl
└── simple/
    └── annotated_instances.jsonl
```

## 🔄 **Managing Projects**

### **Check Current Project:**
```bash
# View current config
cat /opt/potato/config.yaml | grep "annotation_task_name"

# Check service status
sudo systemctl status potato
```

### **Switch Back to Previous:**
```bash
# Restore from backup
ls /opt/potato/config.yaml.backup.*
cp /opt/potato/config.yaml.backup.YYYYMMDD_HHMMSS /opt/potato/config.yaml
sudo systemctl restart potato
```

### **View Project Data:**
```bash
# List annotation files
ls -la /app/annotation_output/

# View annotations
cat /app/annotation_output/annotated_instances.jsonl | head -5
```

## 🧪 **Testing Different Projects**

### **Quick Test Workflow:**
1. **List projects:** `./switch-project.sh list`
2. **Switch project:** `./switch-project.sh sentiment_analysis/sentiment-analysis.yaml`
3. **Test annotation:** Visit your URL and submit test annotations
4. **Check data:** `ls -la /app/annotation_output/`
5. **Switch again:** Try a different project type

### **Compare Annotation Types:**
- **Radio buttons:** Single choice (sentiment analysis)
- **Checkboxes:** Multiple choice (simple examples)  
- **Likert scales:** Rating scales (empathy)
- **Text input:** Free text (question answering)
- **Span selection:** Text highlighting (NER tasks)

## 🚨 **Troubleshooting**

### **Project Won't Switch:**
```bash
# Check config syntax
cd /opt/potato
source venv/bin/activate
python -c "import yaml; yaml.safe_load(open('config.yaml'))"

# Check service logs
sudo journalctl -u potato -n 20
```

### **Data Files Not Found:**
```bash
# Check if data files exist
ls -la project-hub/sentiment_analysis/data_files/

# Update config paths manually
nano config.yaml
```

### **Service Won't Start:**
```bash
# Restore backup config
cp config.yaml.backup.* config.yaml
sudo systemctl restart potato
```

## 💡 **Best Practices**

1. **Test projects** before sharing with annotators
2. **Backup configs** before major changes
3. **Use descriptive project names** for organization
4. **Monitor data storage** locations for each project
5. **Document your annotation schemes** for consistency

## 🎯 **Quick Commands Reference**

```bash
# List all projects
./switch-project.sh list

# Switch to specific project
./switch-project.sh PROJECT_NAME/CONFIG_FILE.yaml

# Start web manager
python3 project-manager.py

# Setup multi-project mode
./setup-multi-project.sh

# Quick restart after config changes
./quick-restart.sh

# View current project info
cat config.yaml | grep -E "(server_name|annotation_task_name)"
```

Now you can easily switch between different annotation types and manage multiple projects! 🚀