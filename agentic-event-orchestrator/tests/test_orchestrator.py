import pytest
import asyncio
from src.orchestrator import EventOrchestrator
from src.models import AgentEvent

class MockWebSocket:
    def __init__(self):
        self.sent_messages = []

    async def send(self, message: str):
        self.sent_messages.append(message)

@pytest.mark.asyncio
async def test_publish_and_consume():
    orchestrator = EventOrchestrator()
    received_events = []

    async def callback(payload):
        received_events.append(payload)

    await orchestrator.start_consumer_loop(callback)

    event = AgentEvent(
        event_id="evt_001",
        agent_id="agent_alpha",
        event_type="tool_execution",
        payload={"tool": "orderbook_lookup", "status": "initiated"}
    )
    
    latency = await orchestrator.publish_event("agent_events", event.model_dump())
    assert latency < 10.0  # Asserts sub-10ms routing overhead
    
    await asyncio.sleep(0.2)

    assert len(received_events) == 1
    assert received_events[0]["event_id"] == "evt_001"
    assert received_events[0]["agent_id"] == "agent_alpha"

    orchestrator.stop()

@pytest.mark.asyncio
async def test_websocket_manager():
    orchestrator = EventOrchestrator()
    ws = MockWebSocket()

    orchestrator.manager.connect(ws)
    assert ws in orchestrator.manager.active_connections

    await orchestrator.manager.broadcast("test_broadcast_message")
    assert len(ws.sent_messages) == 1
    assert ws.sent_messages[0] == "test_broadcast_message"

    orchestrator.manager.disconnect(ws)
    assert ws not in orchestrator.manager.active_connections
