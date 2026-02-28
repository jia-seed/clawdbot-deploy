FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create frontend mount point
RUN mkdir -p /app/frontend

# Expose port
EXPOSE 8000

# Run the server
CMD ["python", "server.py"]
