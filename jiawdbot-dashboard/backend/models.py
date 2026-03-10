"""Pydantic models for the agent visualization system."""
from pydantic import BaseModel
from typing import Optional, Any
from datetime import datetime


class Agent(BaseModel):
    id: str
    name: str
    type: str  # 'main' or 'subagent'
    created_at: datetime
    parent_id: Optional[str] = None


class Session(BaseModel):
    id: str
    agent_id: str
    label: Optional[str] = None
    channel: Optional[str] = None
    started_at: datetime
    model: Optional[str] = None
    cwd: Optional[str] = None


class Action(BaseModel):
    id: str
    session_id: str
    type: str  # 'tool_call', 'message', 'completion', 'model_change', etc.
    name: Optional[str] = None  # tool name if tool_call
    timestamp: datetime
    details: Optional[dict[str, Any]] = None
    parent_id: Optional[str] = None  # for action chaining


class ToolUsage(BaseModel):
    tool_name: str
    count: int
    last_used: datetime


class SessionStats(BaseModel):
    total_sessions: int
    total_actions: int
    total_tool_calls: int
    agents: int
    subagents: int


class GraphNode(BaseModel):
    id: str
    label: str
    type: str
    properties: dict[str, Any]


class GraphEdge(BaseModel):
    source: str
    target: str
    type: str
    properties: Optional[dict[str, Any]] = None


class GraphData(BaseModel):
    nodes: list[GraphNode]
    edges: list[GraphEdge]
