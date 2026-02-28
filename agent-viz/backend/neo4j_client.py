"""Neo4j database client for agent visualization."""
import os
from neo4j import GraphDatabase
from dotenv import load_dotenv
from datetime import datetime
from typing import Optional, Any

load_dotenv()


class Neo4jClient:
    def __init__(self):
        self.uri = os.getenv("NEO4J_URI", "bolt://localhost:7687")
        self.user = os.getenv("NEO4J_USER", "neo4j")
        self.password = os.getenv("NEO4J_PASSWORD", "agentvizsecret")
        self.driver = None

    def connect(self):
        """Connect to Neo4j."""
        self.driver = GraphDatabase.driver(self.uri, auth=(self.user, self.password))
        self._ensure_constraints()

    def close(self):
        """Close the connection."""
        if self.driver:
            self.driver.close()

    def _ensure_constraints(self):
        """Create indexes and constraints."""
        with self.driver.session() as session:
            # Uniqueness constraints
            session.run("CREATE CONSTRAINT IF NOT EXISTS FOR (a:Agent) REQUIRE a.id IS UNIQUE")
            session.run("CREATE CONSTRAINT IF NOT EXISTS FOR (s:Session) REQUIRE s.id IS UNIQUE")
            session.run("CREATE CONSTRAINT IF NOT EXISTS FOR (ac:Action) REQUIRE ac.id IS UNIQUE")
            # Indexes for faster lookups
            session.run("CREATE INDEX IF NOT EXISTS FOR (a:Action) ON (a.timestamp)")
            session.run("CREATE INDEX IF NOT EXISTS FOR (a:Action) ON (a.type)")
            session.run("CREATE INDEX IF NOT EXISTS FOR (s:Session) ON (s.started_at)")

    def create_agent(self, agent_id: str, name: str, agent_type: str, 
                     created_at: datetime, parent_id: Optional[str] = None):
        """Create or update an agent node."""
        with self.driver.session() as session:
            session.run("""
                MERGE (a:Agent {id: $id})
                SET a.name = $name,
                    a.type = $type,
                    a.created_at = $created_at
            """, id=agent_id, name=name, type=agent_type, created_at=created_at.isoformat())
            
            if parent_id:
                session.run("""
                    MATCH (parent:Agent {id: $parent_id})
                    MATCH (child:Agent {id: $child_id})
                    MERGE (parent)-[:SPAWNED]->(child)
                """, parent_id=parent_id, child_id=agent_id)

    def create_session(self, session_id: str, agent_id: str, label: Optional[str],
                       channel: Optional[str], started_at: datetime, 
                       model: Optional[str], cwd: Optional[str]):
        """Create or update a session node."""
        with self.driver.session() as session:
            session.run("""
                MERGE (s:Session {id: $id})
                SET s.label = $label,
                    s.channel = $channel,
                    s.started_at = $started_at,
                    s.model = $model,
                    s.cwd = $cwd
            """, id=session_id, label=label, channel=channel, 
                started_at=started_at.isoformat(), model=model, cwd=cwd)
            
            session.run("""
                MATCH (a:Agent {id: $agent_id})
                MATCH (s:Session {id: $session_id})
                MERGE (a)-[:HAS_SESSION]->(s)
            """, agent_id=agent_id, session_id=session_id)

    def create_action(self, action_id: str, session_id: str, action_type: str,
                      name: Optional[str], timestamp: datetime,
                      details: Optional[dict], parent_id: Optional[str] = None):
        """Create an action node."""
        with self.driver.session() as session:
            # Create the action
            session.run("""
                MERGE (ac:Action {id: $id})
                SET ac.type = $type,
                    ac.name = $name,
                    ac.timestamp = $timestamp,
                    ac.details = $details
            """, id=action_id, type=action_type, name=name,
                timestamp=timestamp.isoformat(), details=str(details) if details else None)
            
            # Link to session
            session.run("""
                MATCH (s:Session {id: $session_id})
                MATCH (ac:Action {id: $action_id})
                MERGE (s)-[:CONTAINS]->(ac)
            """, session_id=session_id, action_id=action_id)
            
            # Link to parent action for temporal ordering
            if parent_id:
                session.run("""
                    MATCH (parent:Action {id: $parent_id})
                    MATCH (child:Action {id: $child_id})
                    MERGE (parent)-[:FOLLOWED_BY]->(child)
                """, parent_id=parent_id, child_id=action_id)

    def get_all_agents(self) -> list[dict]:
        """Get all agents."""
        with self.driver.session() as session:
            result = session.run("""
                MATCH (a:Agent)
                OPTIONAL MATCH (a)-[:SPAWNED]->(child:Agent)
                OPTIONAL MATCH (parent:Agent)-[:SPAWNED]->(a)
                RETURN a, collect(DISTINCT child.id) as children, parent.id as parent
                ORDER BY a.created_at DESC
            """)
            return [{"agent": dict(r["a"]), "children": r["children"], "parent": r["parent"]} 
                    for r in result]

    def get_recent_sessions(self, limit: int = 50) -> list[dict]:
        """Get recent sessions with action counts."""
        with self.driver.session() as session:
            result = session.run("""
                MATCH (s:Session)
                OPTIONAL MATCH (s)-[:CONTAINS]->(ac:Action)
                WITH s, count(ac) as action_count
                RETURN s, action_count
                ORDER BY s.started_at DESC
                LIMIT $limit
            """, limit=limit)
            return [{"session": dict(r["s"]), "action_count": r["action_count"]} 
                    for r in result]

    def get_session_with_actions(self, session_id: str) -> dict:
        """Get a session with all its actions."""
        with self.driver.session() as session:
            # Get session
            sess_result = session.run("""
                MATCH (s:Session {id: $id})
                OPTIONAL MATCH (a:Agent)-[:HAS_SESSION]->(s)
                RETURN s, a
            """, id=session_id)
            sess_record = sess_result.single()
            
            # Get actions
            actions_result = session.run("""
                MATCH (s:Session {id: $id})-[:CONTAINS]->(ac:Action)
                RETURN ac
                ORDER BY ac.timestamp ASC
            """, id=session_id)
            
            return {
                "session": dict(sess_record["s"]) if sess_record else None,
                "agent": dict(sess_record["a"]) if sess_record and sess_record["a"] else None,
                "actions": [dict(r["ac"]) for r in actions_result]
            }

    def get_graph_data(self, limit: int = 100) -> dict:
        """Get graph data for visualization."""
        with self.driver.session() as session:
            # Get nodes
            result = session.run("""
                MATCH (a:Agent)
                OPTIONAL MATCH (a)-[:HAS_SESSION]->(s:Session)
                OPTIONAL MATCH (s)-[:CONTAINS]->(ac:Action)
                WITH a, s, ac
                ORDER BY ac.timestamp DESC
                LIMIT $limit
                RETURN 
                    collect(DISTINCT {id: a.id, label: a.name, type: 'Agent', props: properties(a)}) as agents,
                    collect(DISTINCT {id: s.id, label: coalesce(s.label, s.id), type: 'Session', props: properties(s)}) as sessions,
                    collect(DISTINCT {id: ac.id, label: coalesce(ac.name, ac.type), type: 'Action', props: properties(ac)}) as actions
            """, limit=limit)
            
            record = result.single()
            nodes = []
            if record:
                for a in record["agents"]:
                    if a["id"]:
                        nodes.append(a)
                for s in record["sessions"]:
                    if s["id"]:
                        nodes.append(s)
                for ac in record["actions"]:
                    if ac["id"]:
                        nodes.append(ac)
            
            # Get edges
            edges_result = session.run("""
                MATCH (a)-[r]->(b)
                WHERE (a:Agent OR a:Session OR a:Action) AND (b:Agent OR b:Session OR b:Action)
                RETURN a.id as source, b.id as target, type(r) as type
                LIMIT $limit
            """, limit=limit * 3)
            
            edges = [{"source": r["source"], "target": r["target"], "type": r["type"]} 
                     for r in edges_result if r["source"] and r["target"]]
            
            return {"nodes": nodes, "edges": edges}

    def get_stats(self) -> dict:
        """Get aggregate statistics."""
        with self.driver.session() as session:
            result = session.run("""
                OPTIONAL MATCH (s:Session) WITH count(s) as sessions
                OPTIONAL MATCH (ac:Action) WITH sessions, count(ac) as actions
                OPTIONAL MATCH (tc:Action) WHERE tc.type = 'tool_call' WITH sessions, actions, count(tc) as tool_calls
                OPTIONAL MATCH (a:Agent) WHERE a.type = 'main' WITH sessions, actions, tool_calls, count(a) as agents
                OPTIONAL MATCH (sa:Agent) WHERE sa.type = 'subagent' WITH sessions, actions, tool_calls, agents, count(sa) as subagents
                RETURN sessions, actions, tool_calls, agents, subagents
            """)
            record = result.single()
            if record:
                return {
                    "total_sessions": record["sessions"],
                    "total_actions": record["actions"],
                    "total_tool_calls": record["tool_calls"],
                    "agents": record["agents"],
                    "subagents": record["subagents"]
                }
            return {"total_sessions": 0, "total_actions": 0, "total_tool_calls": 0, "agents": 0, "subagents": 0}

    def get_tool_usage(self) -> list[dict]:
        """Get tool usage statistics."""
        with self.driver.session() as session:
            result = session.run("""
                MATCH (ac:Action)
                WHERE ac.type = 'tool_call' AND ac.name IS NOT NULL
                WITH ac.name as tool, count(*) as usage, max(ac.timestamp) as last_used
                RETURN tool, usage, last_used
                ORDER BY usage DESC
            """)
            return [{"tool": r["tool"], "usage": r["usage"], "last_used": r["last_used"]} 
                    for r in result]

    def session_exists(self, session_id: str) -> bool:
        """Check if a session has been synced."""
        with self.driver.session() as session:
            result = session.run("""
                MATCH (s:Session {id: $id})
                RETURN count(s) > 0 as exists
            """, id=session_id)
            record = result.single()
            return record["exists"] if record else False

    def clear_all(self):
        """Clear all data (for testing)."""
        with self.driver.session() as session:
            session.run("MATCH (n) DETACH DELETE n")


# Singleton instance
_client: Optional[Neo4jClient] = None


def get_client() -> Neo4jClient:
    """Get the Neo4j client singleton."""
    global _client
    if _client is None:
        _client = Neo4jClient()
        _client.connect()
    return _client
