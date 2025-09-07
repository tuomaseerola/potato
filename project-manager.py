#!/usr/bin/env python3
"""
Simple web interface to manage Potato annotation projects
Run this alongside your main Potato service
"""

from flask import Flask, render_template_string, request, redirect, url_for, flash
import subprocess
import os
import yaml
import glob
from datetime import datetime

app = Flask(__name__)
app.secret_key = 'potato-project-manager-secret-key'

APP_DIR = '/opt/potato'

# HTML template for the project manager
PROJECT_MANAGER_TEMPLATE = '''
<!DOCTYPE html>
<html>
<head>
    <title>🥔 Potato Project Manager</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #d35400; border-bottom: 3px solid #d35400; padding-bottom: 10px; }
        .project-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin: 20px 0; }
        .project-card { border: 1px solid #ddd; padding: 20px; border-radius: 8px; background: #fafafa; }
        .project-card.active { border-color: #27ae60; background: #e8f5e8; }
        .project-title { font-size: 18px; font-weight: bold; color: #2c3e50; margin-bottom: 10px; }
        .project-description { color: #7f8c8d; margin-bottom: 15px; }
        .btn { padding: 8px 16px; margin: 5px; border: none; border-radius: 4px; cursor: pointer; text-decoration: none; display: inline-block; }
        .btn-primary { background: #3498db; color: white; }
        .btn-success { background: #27ae60; color: white; }
        .btn-warning { background: #f39c12; color: white; }
        .btn-danger { background: #e74c3c; color: white; }
        .btn:hover { opacity: 0.8; }
        .status { padding: 5px 10px; border-radius: 3px; font-size: 12px; font-weight: bold; }
        .status.running { background: #d5f4e6; color: #27ae60; }
        .status.stopped { background: #fadbd8; color: #e74c3c; }
        .flash-messages { margin: 20px 0; }
        .flash { padding: 10px; border-radius: 4px; margin: 5px 0; }
        .flash.success { background: #d5f4e6; color: #27ae60; border: 1px solid #27ae60; }
        .flash.error { background: #fadbd8; color: #e74c3c; border: 1px solid #e74c3c; }
        .current-project { background: #e8f4fd; border: 2px solid #3498db; padding: 15px; border-radius: 8px; margin: 20px 0; }
        .logs { background: #2c3e50; color: #ecf0f1; padding: 15px; border-radius: 4px; font-family: monospace; font-size: 12px; max-height: 200px; overflow-y: auto; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🥔 Potato Project Manager</h1>
        
        {% with messages = get_flashed_messages(with_categories=true) %}
            {% if messages %}
                <div class="flash-messages">
                    {% for category, message in messages %}
                        <div class="flash {{ category }}">{{ message }}</div>
                    {% endfor %}
                </div>
            {% endif %}
        {% endwith %}
        
        <div class="current-project">
            <h3>Current Active Project</h3>
            <p><strong>{{ current_project.name }}</strong> - {{ current_project.description }}</p>
            <p>Status: <span class="status {{ 'running' if current_project.running else 'stopped' }}">
                {{ 'Running' if current_project.running else 'Stopped' }}
            </span></p>
            {% if current_project.running %}
                <p>🌐 <a href="{{ current_project.url }}" target="_blank">Access Annotation Tool</a></p>
            {% endif %}
        </div>
        
        <h2>Available Projects</h2>
        <div class="project-grid">
            {% for project in projects %}
            <div class="project-card {{ 'active' if project.is_current else '' }}">
                <div class="project-title">{{ project.name }}</div>
                <div class="project-description">{{ project.description }}</div>
                <p><strong>Type:</strong> {{ project.annotation_type }}</p>
                <p><strong>Config:</strong> {{ project.config_file }}</p>
                
                <div style="margin-top: 15px;">
                    {% if not project.is_current %}
                        <a href="{{ url_for('switch_project', project_name=project.name) }}" class="btn btn-primary">Switch to This Project</a>
                    {% else %}
                        <span class="btn btn-success">Currently Active</span>
                    {% endif %}
                    
                    {% if project.has_service %}
                        {% if project.service_running %}
                            <a href="{{ url_for('stop_service', service_name=project.service_name) }}" class="btn btn-warning">Stop Service</a>
                        {% else %}
                            <a href="{{ url_for('start_service', service_name=project.service_name) }}" class="btn btn-success">Start Service</a>
                        {% endif %}
                        <a href="{{ url_for('view_logs', service_name=project.service_name) }}" class="btn btn-primary">View Logs</a>
                    {% endif %}
                </div>
            </div>
            {% endfor %}
        </div>
        
        <h2>Quick Actions</h2>
        <div style="margin: 20px 0;">
            <a href="{{ url_for('restart_main_service') }}" class="btn btn-warning">Restart Main Service</a>
            <a href="{{ url_for('view_logs', service_name='potato') }}" class="btn btn-primary">View Main Service Logs</a>
            <a href="{{ url_for('setup_multi_project') }}" class="btn btn-success">Setup Multi-Project Mode</a>
        </div>
        
        {% if logs %}
        <h2>Service Logs</h2>
        <div class="logs">{{ logs }}</div>
        {% endif %}
        
        <hr style="margin: 30px 0;">
        <p style="text-align: center; color: #7f8c8d;">
            Potato Project Manager | 
            <a href="https://potato-annotation.readthedocs.io/" target="_blank">Documentation</a> | 
            <a href="https://github.com/tuomaseerola/potato" target="_blank">GitHub</a>
        </p>
    </div>
</body>
</html>
'''

def get_available_projects():
    """Get list of available projects from project-hub"""
    projects = []
    project_hub_dir = os.path.join(APP_DIR, 'project-hub')
    
    for project_dir in glob.glob(os.path.join(project_hub_dir, '*/')):
        project_name = os.path.basename(project_dir.rstrip('/'))
        configs_dir = os.path.join(project_dir, 'configs')
        
        if os.path.exists(configs_dir):
            for config_file in glob.glob(os.path.join(configs_dir, '*.yaml')):
                try:
                    with open(config_file, 'r') as f:
                        config = yaml.safe_load(f)
                    
                    # Determine annotation type
                    annotation_schemes = config.get('annotation_schemes', [])
                    annotation_type = 'Unknown'
                    if annotation_schemes:
                        annotation_type = annotation_schemes[0].get('annotation_type', 'Unknown')
                    
                    projects.append({
                        'name': f"{project_name}_{os.path.splitext(os.path.basename(config_file))[0]}",
                        'display_name': project_name.replace('_', ' ').title(),
                        'description': config.get('annotation_task_name', 'No description'),
                        'annotation_type': annotation_type,
                        'config_file': config_file,
                        'project_dir': project_name,
                        'is_current': False,
                        'has_service': os.path.exists(f'/etc/systemd/system/potato-{project_name}.service'),
                        'service_name': f'potato-{project_name}',
                        'service_running': False
                    })
                except Exception as e:
                    print(f"Error reading config {config_file}: {e}")
    
    return projects

def get_current_project():
    """Get information about currently active project"""
    try:
        config_file = os.path.join(APP_DIR, 'config.yaml')
        if os.path.exists(config_file):
            with open(config_file, 'r') as f:
                config = yaml.safe_load(f)
            
            return {
                'name': config.get('server_name', 'Unknown'),
                'description': config.get('annotation_task_name', 'No description'),
                'running': is_service_running('potato'),
                'url': f"http://{request.host.split(':')[0]}"
            }
    except Exception as e:
        print(f"Error reading current config: {e}")
    
    return {
        'name': 'No project active',
        'description': 'No configuration found',
        'running': False,
        'url': ''
    }

def is_service_running(service_name):
    """Check if a systemd service is running"""
    try:
        result = subprocess.run(['systemctl', 'is-active', service_name], 
                              capture_output=True, text=True)
        return result.stdout.strip() == 'active'
    except:
        return False

def get_service_logs(service_name, lines=50):
    """Get recent logs from a service"""
    try:
        result = subprocess.run(['journalctl', '-u', service_name, '-n', str(lines), '--no-pager'], 
                              capture_output=True, text=True)
        return result.stdout
    except:
        return "Could not retrieve logs"

@app.route('/')
def index():
    projects = get_available_projects()
    current_project = get_current_project()
    
    # Update service status for projects
    for project in projects:
        if project['has_service']:
            project['service_running'] = is_service_running(project['service_name'])
    
    return render_template_string(PROJECT_MANAGER_TEMPLATE, 
                                projects=projects, 
                                current_project=current_project)

@app.route('/switch/<project_name>')
def switch_project(project_name):
    try:
        # Find the project
        projects = get_available_projects()
        project = next((p for p in projects if p['name'] == project_name), None)
        
        if not project:
            flash('Project not found', 'error')
            return redirect(url_for('index'))
        
        # Copy config file
        subprocess.run(['cp', project['config_file'], os.path.join(APP_DIR, 'config.yaml')])
        
        # Restart main service
        subprocess.run(['systemctl', 'restart', 'potato'])
        
        flash(f'Switched to project: {project["display_name"]}', 'success')
    except Exception as e:
        flash(f'Error switching project: {str(e)}', 'error')
    
    return redirect(url_for('index'))

@app.route('/start/<service_name>')
def start_service(service_name):
    try:
        subprocess.run(['systemctl', 'start', service_name])
        flash(f'Started service: {service_name}', 'success')
    except Exception as e:
        flash(f'Error starting service: {str(e)}', 'error')
    
    return redirect(url_for('index'))

@app.route('/stop/<service_name>')
def stop_service(service_name):
    try:
        subprocess.run(['systemctl', 'stop', service_name])
        flash(f'Stopped service: {service_name}', 'success')
    except Exception as e:
        flash(f'Error stopping service: {str(e)}', 'error')
    
    return redirect(url_for('index'))

@app.route('/restart')
def restart_main_service():
    try:
        subprocess.run(['systemctl', 'restart', 'potato'])
        flash('Restarted main Potato service', 'success')
    except Exception as e:
        flash(f'Error restarting service: {str(e)}', 'error')
    
    return redirect(url_for('index'))

@app.route('/logs/<service_name>')
def view_logs(service_name):
    logs = get_service_logs(service_name)
    projects = get_available_projects()
    current_project = get_current_project()
    
    return render_template_string(PROJECT_MANAGER_TEMPLATE, 
                                projects=projects, 
                                current_project=current_project,
                                logs=logs)

@app.route('/setup-multi')
def setup_multi_project():
    flash('Multi-project setup would run here. Use the setup-multi-project.sh script manually.', 'success')
    return redirect(url_for('index'))

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=False)
EOF