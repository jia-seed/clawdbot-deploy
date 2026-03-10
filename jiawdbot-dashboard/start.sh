#!/bin/bash
# Quick start script for jiawdbot-dashboard

set -e

cd "$(dirname "$0")/.."

echo "🚀 Starting Agent-Viz..."

# Check if Docker is available
if command -v docker &> /dev/null; then
    echo "📦 Using Docker Compose..."
    docker-compose up -d
    
    echo "⏳ Waiting for services to start..."
    sleep 10
    
    echo ""
    echo "✅ Agent-Viz is running!"
    echo ""
    echo "   Dashboard:  http://localhost:8000"
    echo "   Neo4j:      http://localhost:7474"
    echo "              (user: neo4j, pass: agentvizsecret)"
    echo ""
    echo "To stop: docker-compose down"
else
    echo "📦 Docker not found, using local Python..."
    
    # Check if Neo4j is running
    if ! nc -z localhost 7687 2>/dev/null; then
        echo "⚠️  Neo4j not running on port 7687"
        echo "   Start Neo4j first, or use Docker: docker-compose up neo4j -d"
        exit 1
    fi
    
    cd backend
    
    # Create venv if needed
    if [ ! -d "venv" ]; then
        echo "Creating virtual environment..."
        python3 -m venv venv
    fi
    
    source venv/bin/activate
    pip install -q -r requirements.txt
    
    # Copy env if needed
    if [ ! -f ".env" ]; then
        cp .env.example .env
        echo "📝 Created .env from template - edit as needed"
    fi
    
    echo ""
    echo "🔄 Running initial sync..."
    python sync_sessions.py
    
    echo ""
    echo "🌐 Starting server..."
    python server.py
fi
