#!/usr/bin/env python3
"""
Sync Clawdbot session logs to Neo4j.

Parses JSONL session files and creates graph nodes/relationships.
"""
import os
import json
import glob
import re
from datetime import datetime
from pathlib import Path
from typing import Optional
from dotenv import load_dotenv

from neo4j_client import get_client

load_dotenv()

SESSION_PATH = os.getenv("SESSION_PATH", "/opt/clawdbot-1/.clawdbot/agents/main/sessions/")


def parse_timestamp(ts: str) -> datetime:
    """Parse ISO timestamp to datetime."""
    # Handle various formats
    ts = ts.replace("Z", "+00:00")
    try:
        return datetime.fromisoformat(ts)
    except ValueError:
        # Fallback
        return datetime.now()


def extract_session_label(session_id: str, entries: list) -> Optional[str]:
    """Extract a readable label from session entries."""
    # Look for channel info in first few entries
    for entry in entries[:10]:
        if entry.get("type") == "custom":
            data = entry.get("data", {})
            if "channel" in str(data):
                return f"Session via {data.get('channel', 'unknown')}"
        
        if entry.get("type") == "message":
            msg = entry.get("message", {})
            if msg.get("role") == "user":
                content = msg.get("content", [])
                if isinstance(content, list) and content:
                    first = content[0]
                    if isinstance(first, dict) and first.get("type") == "text":
                        text = first.get("text", "")[:50]
                        return text.split("\n")[0]
    
    return None


def extract_agent_info(session_id: str, entries: list) -> dict:
    """Extract agent info from session entries."""
    agent_info = {
        "id": "main",
        "name": "main",
        "type": "main",
        "parent_id": None
    }
    
    # Check if this is a subagent session
    for entry in entries[:20]:
        if entry.get("type") == "custom" and entry.get("customType") == "model-snapshot":
            # Check for subagent markers in the context
            pass
        
        if entry.get("type") == "message":
            msg = entry.get("message", {})
            content = msg.get("content", [])
            if isinstance(content, list):
                for c in content:
                    if isinstance(c, dict) and c.get("type") == "text":
                        text = c.get("text", "")
                        # Check for subagent context
                        if "You are a **subagent**" in text:
                            # Extract subagent info
                            match = re.search(r"Your session: agent:main:subagent:([a-f0-9-]+)", text)
                            if match:
                                agent_info["id"] = f"subagent:{match.group(1)[:8]}"
                                agent_info["name"] = f"Subagent {match.group(1)[:8]}"
                                agent_info["type"] = "subagent"
                            
                            # Find parent session
                            parent_match = re.search(r"Requester session: ([^\s]+)", text)
                            if parent_match:
                                agent_info["parent_id"] = "main"
                            
                            # Try to get label
                            label_match = re.search(r"Label: ([^\n]+)", text)
                            if label_match:
                                agent_info["name"] = label_match.group(1).strip()
                            
                            return agent_info
    
    return agent_info


def parse_session_file(filepath: str, force: bool = False) -> dict:
    """Parse a single session JSONL file."""
    client = get_client()
    session_id = Path(filepath).stem
    
    # Skip deleted sessions
    if ".deleted." in filepath:
        return {"session_id": session_id, "status": "skipped", "reason": "deleted"}
    
    # Skip lock files
    if filepath.endswith(".lock"):
        return {"session_id": session_id, "status": "skipped", "reason": "lock_file"}
    
    # Check if already synced
    if not force and client.session_exists(session_id):
        return {"session_id": session_id, "status": "skipped", "reason": "already_synced"}
    
    entries = []
    try:
        with open(filepath, "r") as f:
            for line in f:
                line = line.strip()
                if line:
                    try:
                        entries.append(json.loads(line))
                    except json.JSONDecodeError:
                        continue
    except Exception as e:
        return {"session_id": session_id, "status": "error", "reason": str(e)}
    
    if not entries:
        return {"session_id": session_id, "status": "skipped", "reason": "empty"}
    
    # Extract session metadata
    session_meta = None
    for entry in entries:
        if entry.get("type") == "session":
            session_meta = entry
            break
    
    if not session_meta:
        return {"session_id": session_id, "status": "skipped", "reason": "no_session_meta"}
    
    # Get agent info
    agent_info = extract_agent_info(session_id, entries)
    
    # Create agent
    session_time = parse_timestamp(session_meta.get("timestamp", datetime.now().isoformat()))
    client.create_agent(
        agent_id=agent_info["id"],
        name=agent_info["name"],
        agent_type=agent_info["type"],
        created_at=session_time,
        parent_id=agent_info["parent_id"]
    )
    
    # Extract model info
    model = None
    channel = None
    for entry in entries[:20]:
        if entry.get("type") == "model_change":
            model = entry.get("modelId")
        if entry.get("type") == "custom":
            data = entry.get("data", {})
            if "channel" in str(data):
                channel = data.get("channel")
    
    # Create session
    label = extract_session_label(session_id, entries)
    client.create_session(
        session_id=session_id,
        agent_id=agent_info["id"],
        label=label,
        channel=channel,
        started_at=session_time,
        model=model,
        cwd=session_meta.get("cwd")
    )
    
    # Process actions
    action_count = 0
    tool_call_count = 0
    prev_action_id = None
    
    for entry in entries:
        entry_type = entry.get("type")
        entry_id = entry.get("id")
        
        if not entry_id:
            continue
        
        timestamp = parse_timestamp(entry.get("timestamp", datetime.now().isoformat()))
        
        # Determine action type and details
        action_type = None
        action_name = None
        details = None
        
        if entry_type == "message":
            msg = entry.get("message", {})
            role = msg.get("role")
            
            if role == "assistant":
                content = msg.get("content", [])
                # Check for tool calls
                for item in content if isinstance(content, list) else []:
                    if isinstance(item, dict) and item.get("type") == "toolCall":
                        action_type = "tool_call"
                        action_name = item.get("name")
                        tool_call_count += 1
                        details = {"tool": action_name, "args_preview": str(item.get("arguments", ""))[:200]}
                        
                        client.create_action(
                            action_id=f"{entry_id}:{action_name}",
                            session_id=session_id,
                            action_type=action_type,
                            name=action_name,
                            timestamp=timestamp,
                            details=details,
                            parent_id=prev_action_id
                        )
                        prev_action_id = f"{entry_id}:{action_name}"
                        action_count += 1
                
                # Also track the completion itself
                if msg.get("stopReason") == "stop":
                    action_type = "completion"
                    action_name = "assistant_response"
                    usage = entry.get("message", {}).get("usage", {})
                    details = {
                        "model": entry.get("message", {}).get("model"),
                        "tokens": usage.get("totalTokens"),
                        "cost": usage.get("cost", {}).get("total")
                    }
            
            elif role == "user":
                action_type = "user_message"
                action_name = "user_input"
            
            elif role == "toolResult":
                action_type = "tool_result"
                action_name = msg.get("toolName")
                details = {"is_error": entry.get("isError", False)}
        
        elif entry_type == "model_change":
            action_type = "model_change"
            action_name = entry.get("modelId")
            details = {"provider": entry.get("provider")}
        
        elif entry_type == "thinking_level_change":
            action_type = "thinking_change"
            action_name = entry.get("thinkingLevel")
        
        if action_type and action_type not in ["tool_call"]:  # tool_call already handled above
            client.create_action(
                action_id=entry_id,
                session_id=session_id,
                action_type=action_type,
                name=action_name,
                timestamp=timestamp,
                details=details,
                parent_id=prev_action_id
            )
            prev_action_id = entry_id
            action_count += 1
    
    return {
        "session_id": session_id,
        "status": "synced",
        "actions": action_count,
        "tool_calls": tool_call_count,
        "agent": agent_info["name"]
    }


def sync_all_sessions(force: bool = False) -> list[dict]:
    """Sync all session files."""
    results = []
    
    pattern = os.path.join(SESSION_PATH, "*.jsonl")
    files = glob.glob(pattern)
    
    print(f"Found {len(files)} session files in {SESSION_PATH}")
    
    for filepath in sorted(files):
        result = parse_session_file(filepath, force=force)
        results.append(result)
        
        status = result.get("status")
        if status == "synced":
            print(f"  ✓ {result['session_id'][:8]}... ({result['actions']} actions, {result['tool_calls']} tool calls)")
        elif status == "skipped":
            reason = result.get("reason", "unknown")
            if reason != "already_synced":
                print(f"  - {result['session_id'][:8]}... (skipped: {reason})")
        else:
            print(f"  ✗ {result['session_id'][:8]}... (error: {result.get('reason')})")
    
    synced = [r for r in results if r["status"] == "synced"]
    print(f"\nSynced {len(synced)} new sessions")
    
    return results


def watch_and_sync():
    """Watch for new session files and sync them."""
    from watchdog.observers import Observer
    from watchdog.events import FileSystemEventHandler
    
    class SessionHandler(FileSystemEventHandler):
        def on_modified(self, event):
            if event.src_path.endswith(".jsonl") and not event.src_path.endswith(".lock"):
                print(f"Session modified: {event.src_path}")
                result = parse_session_file(event.src_path, force=True)
                print(f"  Sync result: {result['status']}")
        
        def on_created(self, event):
            if event.src_path.endswith(".jsonl") and not event.src_path.endswith(".lock"):
                print(f"New session: {event.src_path}")
                result = parse_session_file(event.src_path)
                print(f"  Sync result: {result['status']}")
    
    observer = Observer()
    observer.schedule(SessionHandler(), SESSION_PATH, recursive=False)
    observer.start()
    
    print(f"Watching {SESSION_PATH} for changes...")
    
    try:
        import time
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    
    observer.join()


if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1 and sys.argv[1] == "--watch":
        # Initial sync then watch
        sync_all_sessions()
        watch_and_sync()
    elif len(sys.argv) > 1 and sys.argv[1] == "--force":
        sync_all_sessions(force=True)
    else:
        sync_all_sessions()
