from __future__ import annotations

import json
import logging
import os
import uuid
from collections import deque
from datetime import datetime, timezone
from typing import Deque, List, Optional

import httpx
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field


def utc_now() -> datetime:
    return datetime.now(tz=timezone.utc)


def parse_iso8601(value: str) -> datetime:
    try:
        if value.endswith("Z"):
            value = value[:-1] + "+00:00"
        return datetime.fromisoformat(value)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="Invalid ISO8601 timestamp") from exc


class Message(BaseModel):
    id: str
    author: str
    content: str
    timestamp: datetime
    complete: bool = True


class MessageRequest(BaseModel):
    author: str = Field(..., min_length=1, max_length=64)
    content: str = Field(..., min_length=1, max_length=2000)


class MessageStore:
    def __init__(self, limit: int = 500):
        self._items: Deque[Message] = deque(maxlen=limit)

    def add(self, message: Message) -> Message:
        self._items.append(message)
        return message

    def upsert(self, message: Message) -> Message:
        for index, existing in enumerate(self._items):
            if existing.id == message.id:
                self._items[index] = message
                return message
        self._items.append(message)
        return message

    def query(self, since: Optional[datetime]) -> List[Message]:
        if since is None:
            return list(self._items)
        return [msg for msg in self._items if msg.timestamp > since]


message_limit = int(os.getenv("MESSAGE_LIMIT", "500"))
store = MessageStore(limit=message_limit)

OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434").rstrip("/")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "deepseek-r1:8b")
OLLAMA_HISTORY_LIMIT = int(os.getenv("OLLAMA_HISTORY_LIMIT", "20"))
OLLAMA_SYSTEM_PROMPT = os.getenv(
    "OLLAMA_SYSTEM_PROMPT",
    "You are ChatCommunity, a concise helpful AI chatting with users inside an iOS demo app.",
)
OLLAMA_AUTHOR = os.getenv("OLLAMA_AUTHOR", "Ollama")
OLLAMA_TIMEOUT = float(os.getenv("OLLAMA_TIMEOUT", "120"))

logger = logging.getLogger("chatcommunity")
logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO").upper())

app = FastAPI(title="ChatCommunity Server")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health_check() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/messages", response_model=List[Message])
async def list_messages(since: Optional[str] = Query(default=None)) -> List[Message]:
    since_dt: Optional[datetime] = None
    if since:
        since_dt = parse_iso8601(since)
    messages = store.query(since=since_dt)
    return sorted(messages, key=lambda msg: msg.timestamp)


async def _generate_ai_reply() -> Optional[Message]:
    history = store.query(since=None)
    recent_history = history[-OLLAMA_HISTORY_LIMIT :]

    chat_messages = []
    if OLLAMA_SYSTEM_PROMPT:
        chat_messages.append({"role": "system", "content": OLLAMA_SYSTEM_PROMPT})

    for message in recent_history:
        role = "assistant" if message.author == OLLAMA_AUTHOR else "user"
        chat_messages.append({"role": role, "content": message.content})

    payload = {"model": OLLAMA_MODEL, "messages": chat_messages, "stream": True}

    placeholder = Message(
        id=str(uuid.uuid4()),
        author=OLLAMA_AUTHOR,
        content="正在生成...",
        timestamp=utc_now(),
        complete=False,
    )
    store.add(placeholder)

    content_chunks: List[str] = []
    async with httpx.AsyncClient(timeout=OLLAMA_TIMEOUT) as client:
        async with client.stream("POST", f"{OLLAMA_BASE_URL}/api/chat", json=payload) as response:
            response.raise_for_status()
            async for line in response.aiter_lines():
                if not line:
                    continue
                try:
                    data = json.loads(line)
                except json.JSONDecodeError:
                    logger.warning("Failed to parse Ollama chunk: %s", line)
                    continue
                delta = data.get("message", {}).get("content") or ""
                if delta:
                    content_chunks.append(delta)
                    updated_message = placeholder.model_copy(
                        update={
                            "content": "".join(content_chunks),
                            "timestamp": utc_now(),
                            "complete": data.get("done", False),
                        }
                    )
                    store.upsert(updated_message)

    final_text = "".join(content_chunks).strip() or placeholder.content

    final_message = placeholder.model_copy(
        update={
            "content": final_text,
            "timestamp": utc_now(),
            "complete": True,
        }
    )
    store.upsert(final_message)
    return final_message


@app.post("/messages", response_model=Message, status_code=201)
async def create_message(payload: MessageRequest) -> Message:
    message = Message(
        id=str(uuid.uuid4()),
        author=payload.author,
        content=payload.content,
        timestamp=utc_now(),
    )
    store.add(message)

    try:
        ai_message = await _generate_ai_reply()
    except httpx.HTTPError as exc:
        logger.error("Failed to reach Ollama: %s", exc)
        raise HTTPException(status_code=502, detail="Failed to reach Ollama backend") from exc

    return message


@app.on_event("startup")
async def seed_messages() -> None:
    if not store.query(since=None):
        store.add(
            Message(
                id=str(uuid.uuid4()),
                author="System",
                content="Welcome to ChatCommunity backend!",
                timestamp=utc_now(),
            )
        )
