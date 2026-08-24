from pydantic import BaseModel, Field
from typing import Dict, Any

class AgentEvent(BaseModel):
    event_id: str = Field(..., description="Unique event identifier")
    agent_id: str = Field(..., description="Source agent identifier")
    event_type: str = Field(..., description="Type of agent action (e.g. tool_call, llm_response)")
    payload: Dict[str, Any] = Field(default_factory=dict, description="Event arguments and values")
