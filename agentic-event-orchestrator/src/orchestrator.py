import asyncio
import logging
import time
from typing import Set

try:
    import uvloop
    asyncio.set_event_loop_policy(uvloop.EventLoopPolicy())
except ImportError:
    pass

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("Orchestrator")

class ConnectionManager:
    def __init__(self):
        self.active_connections: Set[any] = set()

    def connect(self, websocket):
        self.active_connections.add(websocket)

    def disconnect(self, websocket):
        self.active_connections.discard(websocket)

    async def broadcast(self, message: str):
        for connection in self.active_connections:
            try:
                await connection.send(message)
            except Exception as e:
                logger.error(f"Error broadcasting message: {e}")

class EventOrchestrator:
    def __init__(self, redis_client=None):
        self.redis = redis_client
        self.manager = ConnectionManager()
        self.fallback_queue = asyncio.Queue()
        self.running = False

    async def publish_event(self, stream_name: str, event_data: dict):
        start_time = time.perf_counter()
        event_data["dispatch_timestamp_ns"] = int(time.time_ns())

        if self.redis:
            try:
                await self.redis.xadd(stream_name, event_data)
            except Exception as e:
                logger.error(f"Redis write error: {e}, falling back to memory queue.")
                await self.fallback_queue.put((stream_name, event_data))
        else:
            await self.fallback_queue.put((stream_name, event_data))

        latency_ms = (time.perf_counter() - start_time) * 1000.0
        return latency_ms

    async def start_consumer_loop(self, callback):
        self.running = True
        self.consumer_task = asyncio.create_task(self._consumer_loop(callback))

    async def _consumer_loop(self, callback):
        while self.running:
            if self.redis:
                try:
                    streams = await self.redis.xread({"agent_events": "0-0"}, count=10, block=100)
                    for stream, messages in streams:
                        for msg_id, payload in messages:
                            await callback(payload)
                except Exception as e:
                    logger.error(f"Redis read error: {e}")
                    await asyncio.sleep(0.01)
            else:
                try:
                    _, payload = await asyncio.wait_for(self.fallback_queue.get(), timeout=0.1)
                    await callback(payload)
                    self.fallback_queue.task_done()
                except asyncio.TimeoutError:
                    continue

    def stop(self):
        self.running = False
        if hasattr(self, "consumer_task"):
            self.consumer_task.cancel()
