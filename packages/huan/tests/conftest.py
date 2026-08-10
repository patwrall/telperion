import pytest
from huan.config import Config
from huan.store import Store


@pytest.fixture
def store(tmp_path):
    return Store(tmp_path / "test.db")


@pytest.fixture
def config():
    return Config()


class FakeResponse:
    def __init__(self, payload=None, status_code=200):
        self._payload = payload or {}
        self.status_code = status_code

    def raise_for_status(self):
        if self.status_code >= 400:
            import httpx

            raise httpx.HTTPStatusError(
                f"{self.status_code}", request=None, response=None
            )

    def json(self):
        return self._payload


class FakeHttp:
    """Scripted httpx.AsyncClient stand-in: pops one response per post."""

    def __init__(self, responses):
        self.responses = list(responses)
        self.requests = []

    async def post(self, url, **kwargs):
        self.requests.append((url, kwargs))
        return self.responses.pop(0)


@pytest.fixture
def chat_reply():
    def make(content, status_code=200):
        return FakeResponse(
            {"choices": [{"message": {"content": content}}]}, status_code
        )

    return make


@pytest.fixture
def fake_http():
    return FakeHttp
