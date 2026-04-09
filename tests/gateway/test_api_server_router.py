"""Router-mode tests for the API server adapter."""

import json

import pytest
from aiohttp import web
from aiohttp.test_utils import TestClient, TestServer

from gateway.config import PlatformConfig
from gateway.platforms.api_server import APIServerAdapter, security_headers_middleware


class FakeContent:
    def __init__(self, chunks):
        self._chunks = list(chunks)

    def __aiter__(self):
        self._iter = iter(self._chunks)
        return self

    async def __anext__(self):
        try:
            return next(self._iter)
        except StopIteration as exc:
            raise StopAsyncIteration from exc


class FakeResponse:
    def __init__(self, *, status=200, payload=None, headers=None, stream_chunks=None):
        self.status = status
        self._payload = payload
        self.headers = headers or {}
        self.content = FakeContent(stream_chunks or [])

    async def text(self):
        if isinstance(self._payload, str):
            return self._payload
        return json.dumps(self._payload or {})

    def release(self):
        return None


class FakeRequestContext:
    def __init__(self, response):
        self._response = response

    async def __aenter__(self):
        return self._response

    async def __aexit__(self, exc_type, exc, tb):
        return False

    def __await__(self):
        async def _return_response():
            return self._response

        return _return_response().__await__()


class FakeClientSession:
    def __init__(self, responses):
        self._responses = responses
        self.requests = []
        self.closed = False

    def request(self, method, url, json=None, headers=None):
        key = (method.upper(), url)
        self.requests.append(
            {
                "method": method.upper(),
                "url": url,
                "json": json,
                "headers": headers or {},
            }
        )
        response = self._responses[key]
        return FakeRequestContext(response)

    async def close(self):
        self.closed = True


def _make_router_adapter() -> APIServerAdapter:
    config = PlatformConfig(
        enabled=True,
        extra={
            "key": "sk-router",
            "router": {
                "default_backend": "hermes",
                "backends": {
                    "hermes": {
                        "model_id": "hermes-agent",
                        "base_url": "http://hermes.test",
                        "api_key": "sk-hermes",
                    },
                    "doubao": {
                        "model_id": "doubao-agent",
                        "base_url": "http://doubao.test",
                        "api_key": "sk-doubao",
                    },
                },
            },
        },
    )
    return APIServerAdapter(config)


def _create_app(adapter: APIServerAdapter) -> web.Application:
    app = web.Application(middlewares=[security_headers_middleware])
    app["api_server_adapter"] = adapter
    app.router.add_get("/v1/models", adapter._handle_models)
    app.router.add_post("/v1/chat/completions", adapter._handle_chat_completions)
    app.router.add_post("/v1/responses", adapter._handle_responses)
    app.router.add_get("/v1/responses/{response_id}", adapter._handle_get_response)
    app.router.add_delete(
        "/v1/responses/{response_id}", adapter._handle_delete_response
    )
    app.router.add_post("/v1/runs", adapter._handle_runs)
    app.router.add_get("/v1/runs/{run_id}/events", adapter._handle_run_events)
    return app


class TestRouterMode:
    @pytest.mark.asyncio
    async def test_models_returns_router_models(self):
        adapter = _make_router_adapter()
        app = _create_app(adapter)

        async with TestClient(TestServer(app)) as cli:
            resp = await cli.get(
                "/v1/models", headers={"Authorization": "Bearer sk-router"}
            )
            assert resp.status == 200
            data = await resp.json()
            assert [item["id"] for item in data["data"]] == [
                "hermes-agent",
                "doubao-agent",
            ]

    @pytest.mark.asyncio
    async def test_chat_completions_routes_by_model_and_rewrites_session_header(self):
        adapter = _make_router_adapter()
        adapter._router_session = FakeClientSession(
            {
                ("POST", "http://doubao.test/v1/chat/completions"): FakeResponse(
                    payload={
                        "id": "chatcmpl_1",
                        "object": "chat.completion",
                        "model": "doubao-agent",
                        "choices": [
                            {
                                "index": 0,
                                "message": {"role": "assistant", "content": "hi"},
                                "finish_reason": "stop",
                            }
                        ],
                        "usage": {
                            "prompt_tokens": 1,
                            "completion_tokens": 1,
                            "total_tokens": 2,
                        },
                    },
                    headers={"X-Hermes-Session-Id": "sess-raw"},
                ),
            }
        )
        app = _create_app(adapter)

        async with TestClient(TestServer(app)) as cli:
            resp = await cli.post(
                "/v1/chat/completions",
                json={
                    "model": "doubao-agent",
                    "messages": [{"role": "user", "content": "hi"}],
                },
                headers={"Authorization": "Bearer sk-router"},
            )
            assert resp.status == 200
            data = await resp.json()
            assert data["model"] == "doubao-agent"
            assert resp.headers["X-Hermes-Session-Id"].startswith("doubao__")
            call = adapter._router_session.requests[0]
            assert call["url"] == "http://doubao.test/v1/chat/completions"
            assert call["headers"]["Authorization"] == "Bearer sk-doubao"

    @pytest.mark.asyncio
    async def test_chat_completions_rejects_conflicting_model_and_session(self):
        adapter = _make_router_adapter()
        public_session = adapter._make_public_token("doubao", "sess-raw")
        app = _create_app(adapter)

        async with TestClient(TestServer(app)) as cli:
            resp = await cli.post(
                "/v1/chat/completions",
                json={
                    "model": "hermes-agent",
                    "messages": [{"role": "user", "content": "hi"}],
                },
                headers={
                    "Authorization": "Bearer sk-router",
                    "X-Hermes-Session-Id": public_session,
                },
            )
            assert resp.status == 400
            data = await resp.json()
            assert "Conflicting routing hints" in data["error"]["message"]

    @pytest.mark.asyncio
    async def test_chat_completions_stream_proxies_sse_and_rewrites_session_header(
        self,
    ):
        adapter = _make_router_adapter()
        adapter._router_session = FakeClientSession(
            {
                ("POST", "http://hermes.test/v1/chat/completions"): FakeResponse(
                    headers={
                        "Content-Type": "text/event-stream",
                        "Cache-Control": "no-cache",
                        "X-Hermes-Session-Id": "sess-123",
                    },
                    stream_chunks=[
                        b'data: {"choices": [{"delta": {"content": "Hi"}}]}\n\n',
                        b"data: [DONE]\n\n",
                    ],
                ),
            }
        )
        app = _create_app(adapter)

        async with TestClient(TestServer(app)) as cli:
            resp = await cli.post(
                "/v1/chat/completions",
                json={
                    "model": "hermes-agent",
                    "messages": [{"role": "user", "content": "hi"}],
                    "stream": True,
                },
                headers={"Authorization": "Bearer sk-router"},
            )
            assert resp.status == 200
            body = await resp.text()
            assert "Hi" in body
            assert "[DONE]" in body
            assert resp.headers["X-Hermes-Session-Id"].startswith("hermes__")

    @pytest.mark.asyncio
    async def test_responses_rewrites_ids_and_tracks_conversation(self):
        adapter = _make_router_adapter()
        adapter._router_session = FakeClientSession(
            {
                ("POST", "http://doubao.test/v1/responses"): FakeResponse(
                    payload={
                        "id": "resp_abc",
                        "object": "response",
                        "status": "completed",
                        "model": "doubao-agent",
                        "output": [],
                    },
                ),
            }
        )
        app = _create_app(adapter)

        async with TestClient(TestServer(app)) as cli:
            resp = await cli.post(
                "/v1/responses",
                json={"model": "doubao-agent", "input": "hi", "conversation": "conv-1"},
                headers={"Authorization": "Bearer sk-router"},
            )
            assert resp.status == 200
            data = await resp.json()
            assert data["id"].startswith("doubao__")
            assert adapter._response_store.get_conversation("conv-1") == data["id"]

    @pytest.mark.asyncio
    async def test_responses_uses_namespaced_previous_response_id(self):
        adapter = _make_router_adapter()
        public_id = adapter._make_public_token("doubao", "resp_prev")
        adapter._router_session = FakeClientSession(
            {
                ("POST", "http://doubao.test/v1/responses"): FakeResponse(
                    payload={
                        "id": "resp_next",
                        "object": "response",
                        "status": "completed",
                        "model": "doubao-agent",
                        "output": [],
                    },
                ),
            }
        )
        app = _create_app(adapter)

        async with TestClient(TestServer(app)) as cli:
            resp = await cli.post(
                "/v1/responses",
                json={"input": "hi", "previous_response_id": public_id},
                headers={"Authorization": "Bearer sk-router"},
            )
            assert resp.status == 200
            call = adapter._router_session.requests[0]
            assert call["json"]["previous_response_id"] == "resp_prev"

    @pytest.mark.asyncio
    async def test_get_and_delete_response_route_by_namespaced_id(self):
        adapter = _make_router_adapter()
        public_id = adapter._make_public_token("hermes", "resp_1")
        adapter._router_session = FakeClientSession(
            {
                ("GET", "http://hermes.test/v1/responses/resp_1"): FakeResponse(
                    payload={"id": "resp_1", "object": "response"}
                ),
                ("DELETE", "http://hermes.test/v1/responses/resp_1"): FakeResponse(
                    payload={"id": "resp_1", "object": "response", "deleted": True}
                ),
            }
        )
        app = _create_app(adapter)

        async with TestClient(TestServer(app)) as cli:
            get_resp = await cli.get(
                f"/v1/responses/{public_id}",
                headers={"Authorization": "Bearer sk-router"},
            )
            assert get_resp.status == 200
            get_data = await get_resp.json()
            assert get_data["id"] == public_id

            delete_resp = await cli.delete(
                f"/v1/responses/{public_id}",
                headers={"Authorization": "Bearer sk-router"},
            )
            assert delete_resp.status == 200
            delete_data = await delete_resp.json()
            assert delete_data["id"] == public_id

    @pytest.mark.asyncio
    async def test_runs_rewrite_run_id_and_forward_raw_tokens(self):
        adapter = _make_router_adapter()
        public_prev = adapter._make_public_token("doubao", "resp_3")
        public_session = adapter._make_public_token("doubao", "sess_3")
        adapter._router_session = FakeClientSession(
            {
                ("POST", "http://doubao.test/v1/runs"): FakeResponse(
                    payload={"run_id": "run_1", "status": "started"}
                ),
            }
        )
        app = _create_app(adapter)

        async with TestClient(TestServer(app)) as cli:
            resp = await cli.post(
                "/v1/runs",
                json={
                    "model": "doubao-agent",
                    "input": "hi",
                    "previous_response_id": public_prev,
                    "session_id": public_session,
                },
                headers={"Authorization": "Bearer sk-router"},
            )
            assert resp.status == 200
            data = await resp.json()
            assert data["run_id"].startswith("doubao__")
            call = adapter._router_session.requests[0]
            assert call["json"]["previous_response_id"] == "resp_3"
            assert call["json"]["session_id"] == "sess_3"

    @pytest.mark.asyncio
    async def test_run_events_rewrite_run_id_inside_sse_payload(self):
        adapter = _make_router_adapter()
        public_run_id = adapter._make_public_token("doubao", "run_inner")
        adapter._router_session = FakeClientSession(
            {
                ("GET", "http://doubao.test/v1/runs/run_inner/events"): FakeResponse(
                    headers={
                        "Content-Type": "text/event-stream",
                        "Cache-Control": "no-cache",
                    },
                    stream_chunks=[
                        b": keepalive\n\n",
                        b'data: {"event": "tool.started", "run_id": "run_inner"}\n\n',
                    ],
                ),
            }
        )
        app = _create_app(adapter)

        async with TestClient(TestServer(app)) as cli:
            resp = await cli.get(
                f"/v1/runs/{public_run_id}/events",
                headers={"Authorization": "Bearer sk-router"},
            )
            assert resp.status == 200
            body = await resp.text()
            assert public_run_id in body
            assert ": keepalive" in body
