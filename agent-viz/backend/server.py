#!/usr/bin/env python3
"""
FastAPI server for the Agent Visualization dashboard.
"""
import os
import threading
from typing import Optional
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from dotenv import load_dotenv
import uvicorn

from neo4j_client import get_client
from sync_sessions import sync_all_sessions, parse_session_file

load_dotenv()

app = FastAPI(
    title="Agent-Viz API",
    description="API for visualizing Clawdbot agent activity",
    version="1.0.0"
)

# CORS for frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
async def startup():
    """Initialize on startup."""
    # Ensure Neo4j connection
    client = get_client()
    print("Connected to Neo4j")
    
    # Initial sync in background
    def initial_sync():
        print("Running initial session sync...")
        sync_all_sessions()
        print("Initial sync complete")
    
    thread = threading.Thread(target=initial_sync)
    thread.daemon = True
    thread.start()


@app.on_event("shutdown")
async def shutdown():
    """Cleanup on shutdown."""
    from neo4j_client import _client
    if _client:
        _client.close()


@app.get("/api/health")
async def health():
    """Health check."""
    return {"status": "ok"}


@app.get("/api/agents")
async def get_agents():
    """Get all agents."""
    client = get_client()
    agents = client.get_all_agents()
    return {"agents": agents}


@app.get("/api/sessions")
async def get_sessions(limit: int = 50):
    """Get recent sessions."""
    client = get_client()
    sessions = client.get_recent_sessions(limit=limit)
    return {"sessions": sessions}


@app.get("/api/session/{session_id}")
async def get_session(session_id: str):
    """Get a session with all its actions."""
    client = get_client()
    data = client.get_session_with_actions(session_id)
    if not data["session"]:
        raise HTTPException(status_code=404, detail="Session not found")
    return data


@app.get("/api/graph")
async def get_graph(limit: int = 100):
    """Get graph data for visualization."""
    client = get_client()
    return client.get_graph_data(limit=limit)


@app.get("/api/stats")
async def get_stats():
    """Get aggregate statistics."""
    client = get_client()
    return client.get_stats()


@app.get("/api/tools")
async def get_tool_usage():
    """Get tool usage statistics."""
    client = get_client()
    return {"tools": client.get_tool_usage()}


@app.post("/api/sync")
async def trigger_sync(force: bool = False):
    """Trigger a manual sync."""
    def do_sync():
        sync_all_sessions(force=force)
    
    thread = threading.Thread(target=do_sync)
    thread.daemon = True
    thread.start()
    
    return {"status": "sync_started"}


# Serve frontend
FRONTEND_PATH = os.getenv("FRONTEND_PATH", os.path.join(os.path.dirname(__file__), "frontend"))

if os.path.exists(FRONTEND_PATH):
    @app.get("/")
    async def serve_frontend():
        return FileResponse(os.path.join(FRONTEND_PATH, "index.html"))
    
    app.mount("/js", StaticFiles(directory=os.path.join(FRONTEND_PATH, "js")), name="js")
    app.mount("/css", StaticFiles(directory=os.path.join(FRONTEND_PATH, "css")), name="css")


if __name__ == "__main__":
    port = int(os.getenv("API_PORT", "8000"))
    uvicorn.run(app, host="0.0.0.0", port=port)
