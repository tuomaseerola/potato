FROM python:3.9-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application code
COPY . .

# Create directories for data persistence
RUN mkdir -p /app/annotation_output
RUN mkdir -p /app/data

# Set environment variables
ENV FLASK_APP=potato/flask_server.py
ENV FLASK_ENV=production
ENV PYTHONPATH=/app

# Expose the port
EXPOSE 8000

# Create a startup script
RUN echo '#!/bin/bash\n\
# Create default config if none exists\n\
if [ ! -f /app/config.yaml ]; then\n\
    cp /app/project-hub/simple_examples/configs/simple-check-box.yaml /app/config.yaml\n\
    # Update config for production\n\
    sed -i "s|data/toy-example.csv|project-hub/simple_examples/data/toy-example.csv|g" /app/config.yaml\n\
    sed -i "s|annotation_output/simple-check-box/|/app/annotation_output/|g" /app/config.yaml\n\
    sed -i "s|\"port\": 9001|\"port\": 8000|g" /app/config.yaml\n\
fi\n\
\n\
# Start the Flask server\n\
cd /app\n\
python potato/flask_server.py start config.yaml -p 8000 --host 0.0.0.0\n\
' > /app/start.sh && chmod +x /app/start.sh

CMD ["/app/start.sh"]