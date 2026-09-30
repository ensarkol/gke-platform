"""Viewer-scoped analysis agent with Vertex AI Gemini function calling."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from google import genai
from google.genai import errors as genai_errors
from google.genai import types
from pydantic import BaseModel, Field

from config import settings
from tools import TOOL_DECLARATIONS, run_tool

SYSTEM_PROMPT = """You are a read-only SRE/DevOps analysis assistant for a Google Cloud + GKE environment.
You have viewer-level access to GCP, Kubernetes (no secrets), and Grafana.
Use tools to gather facts before answering. Never invent metrics or cluster state.
Call independent tools in parallel in a single turn, and stop calling tools as soon as you can answer.
If something is outside your permissions (writes, secrets, destructive actions), refuse politely.
Respond clearly in the user's language (Turkish or English).
"""

app = FastAPI(title="Test Viewer Agent", version="1.0.0")
static_dir = Path(__file__).parent / "static"
if static_dir.exists():
    app.mount("/static", StaticFiles(directory=str(static_dir)), name="static")


class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1)
    history: list[dict[str, str]] = Field(default_factory=list)


class ChatResponse(BaseModel):
    reply: str
    tool_calls: list[dict[str, Any]] = Field(default_factory=list)


def _client() -> genai.Client:
    return genai.Client(
        vertexai=True,
        project=settings.project_id,
        location=settings.gemini_location,
        # Vertex shared quota returns bursty 429s; the SDK does not retry unless told to
        http_options=types.HttpOptions(
            retry_options=types.HttpRetryOptions(attempts=5, initial_delay=2, max_delay=30)
        ),
    )


def _tool_config() -> list[types.Tool]:
    decls = []
    for t in TOOL_DECLARATIONS:
        decls.append(
            types.FunctionDeclaration(
                name=t["name"],
                description=t["description"],
                parameters=t["parameters"],
            )
        )
    return [types.Tool(function_declarations=decls)]


@app.get("/")
def index():
    index_path = static_dir / "index.html"
    if not index_path.exists():
        raise HTTPException(404, "UI not found")
    return FileResponse(index_path)


@app.get("/healthz")
def healthz():
    return {"status": "ok"}


@app.post("/api/chat", response_model=ChatResponse)
def chat(req: ChatRequest):
    if not settings.project_id:
        raise HTTPException(500, "PROJECT_ID is not configured")

    client = _client()
    contents: list[types.Content] = []
    for h in req.history[-10:]:
        role = "user" if h.get("role") == "user" else "model"
        contents.append(types.Content(role=role, parts=[types.Part(text=h.get("content", ""))]))
    contents.append(types.Content(role="user", parts=[types.Part(text=req.message)]))

    tool_trace: list[dict[str, Any]] = []
    max_rounds = 8

    for _ in range(max_rounds):
        candidate = _generate(client, contents, with_tools=True)
        function_calls = [p for p in candidate.content.parts if p.function_call]
        if not function_calls:
            return ChatResponse(reply=_text(candidate), tool_calls=tool_trace)

        contents.append(candidate.content)
        tool_response_parts = []
        for part in function_calls:
            fc = part.function_call
            args = dict(fc.args) if fc.args else {}
            result = run_tool(fc.name, args)
            tool_trace.append({"name": fc.name, "args": args, "result_preview": result[:500]})
            tool_response_parts.append(
                types.Part(
                    function_response=types.FunctionResponse(
                        id=fc.id,
                        name=fc.name,
                        response={"result": result},
                    )
                )
            )
        contents.append(types.Content(role="user", parts=tool_response_parts))

    # Gemini 3.x ignores function_calling_config mode=NONE, so the final turn drops the tools entirely
    contents.append(
        types.Content(
            role="user",
            parts=[types.Part(text="Tool budget reached. Answer now using only the data gathered above.")],
        )
    )
    candidate = _generate(client, contents, with_tools=False)
    return ChatResponse(reply=_text(candidate), tool_calls=tool_trace)


def _generate(client: genai.Client, contents: list[types.Content], with_tools: bool) -> types.Candidate:
    try:
        response = client.models.generate_content(
            model=settings.gemini_model,
            contents=contents,
            config=types.GenerateContentConfig(
                system_instruction=SYSTEM_PROMPT,
                tools=_tool_config() if with_tools else None,
                temperature=0.2,
            ),
        )
    except genai_errors.APIError as e:
        raise HTTPException(503, f"Gemini error {e.code}: {e.message}") from e

    candidate = response.candidates[0] if response.candidates else None
    if not candidate or not candidate.content or not candidate.content.parts:
        raise HTTPException(502, "Model returned an empty response.")
    return candidate


def _text(candidate: types.Candidate) -> str:
    return "\n".join(p.text for p in candidate.content.parts if p.text and not p.thought)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host=settings.host, port=settings.port, reload=False)
