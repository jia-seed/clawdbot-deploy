# Agent-Viz: Clawdbot Activity Visualization Dashboard

Real-time visualization of Clawdbot and subagent actions using Neo4j graph database.

## Architecture

```
┌─────────────────┐     ┌──────────────┐     ┌──────────────┐
│ Session Logs    │────▶│   Backend    │────▶│    Neo4j     │
│ (.jsonl files)  │     │   (Python)   │     │   Database   │
└─────────────────┘     └──────────────┘     └──────────────┘
                                                    │
                                                    ▼
                                            ┌──────────────┐
                                            │   Frontend   │
                                            │   (HTML/JS)  │
                                            └──────────────┘
```

## Features

- **Real-time parsing** of Clawdbot session logs
- **Graph visualization** of agent/session/action relationships
- **Tool call tracking** - see what tools each agent uses
- **Subagent spawning** - visualize parent-child agent relationships
- **Timeline view** of actions

## Prerequisites

- Python 3.9+
- Neo4j Database (local or Docker)
- Node.js (optional, for frontend dev)

## Quick Start

### 1. Start Neo4j

Using Docker:
```bash
docker run -d \
  --name neo4j-agent-viz \
  -p 7474:7474 -p 7687:7687 \
  -e NEO4J_AUTH=neo4j/agentvizsecret \
  -e NEO4J_PLUGINS='["apoc"]' \
  neo4j:5
```

Or use Neo4j Desktop / Aura.

### 2. Install Python Dependencies

```bash
cd backend
pip install -r requirements.txt
```

### 3. Configure Environment

```bash
cp .env.example .env
# Edit .env with your Neo4j credentials and session path
```

### 4. Run the Backend

```bash
# Initial sync (parse all existing sessions)
python sync_sessions.py

# Start the API server with file watcher
python server.py
```

### 5. Open the Frontend

Open `frontend/index.html` in your browser, or serve it:
```bash
cd frontend && python -m http.server 8080
```

Then visit: http://localhost:8080

## Neo4j Schema

### Nodes

- **Agent** - An agent instance (main or subagent)
  - `id`, `name`, `type` (main/subagent), `createdAt`

- **Session** - A conversation session
  - `id`, `label`, `channel`, `startedAt`, `model`

- **Action** - An action taken by an agent
  - `id`, `type` (tool_call/message/completion), `name`, `timestamp`, `details`

### Relationships

- `(Agent)-[:HAS_SESSION]->(Session)`
- `(Agent)-[:SPAWNED]->(Agent)` - subagent creation
- `(Session)-[:CONTAINS]->(Action)`
- `(Action)-[:FOLLOWED_BY]->(Action)` - temporal ordering
- `(Action)-[:USED_TOOL {name}]->(Action)` - tool usage chains

## API Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /api/agents` | List all agents |
| `GET /api/sessions` | List recent sessions |
| `GET /api/session/:id` | Get session details with actions |
| `GET /api/graph` | Get full graph data for visualization |
| `GET /api/stats` | Aggregate statistics |
| `POST /api/sync` | Trigger manual sync |

## Configuration

Environment variables (in `.env`):

```
NEO4J_URI=bolt://localhost:7687
NEO4J_USER=neo4j
NEO4J_PASSWORD=agentvizsecret
SESSION_PATH=/opt/clawdbot-1/.clawdbot/agents/main/sessions/
WATCH_INTERVAL=5
```

## Development

### Backend Structure
```
backend/
├── server.py           # FastAPI server
├── sync_sessions.py    # Session log parser
├── neo4j_client.py     # Neo4j connection and queries
├── models.py           # Pydantic models
└── requirements.txt
```

### Frontend Structure
```
frontend/
├── index.html          # Main dashboard
├── js/
│   ├── app.js          # Main application logic
│   ├── graph.js        # Neo4j visualization (Neovis.js)
│   └── api.js          # API client
└── css/
    └── styles.css
```

## License

MIT
