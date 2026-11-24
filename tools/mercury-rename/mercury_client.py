#!/usr/bin/env python3
"""Mercury 3 client for mercury-rename.

Minimal OpenAI-compatible chat-completions client for Inception Labs'
Mercury API, written against the standard library only (urllib) so the
tool needs no pip installs.

Verified against Inception's official API spec
(https://api.inceptionlabs.ai/openapi.json, fetched 2026-11-24) and the
official docs (https://docs.inceptionlabs.ai):
  - Base URL: https://api.inceptionlabs.ai/v1
  - Chat endpoint: POST /v1/chat/completions
  - Auth: Authorization: Bearer <key>
  - Model id: mercury-3 (Mercury 3, flagship diffusion model;
    supported_endpoints: chat.completions; max output 131,072 tokens)
  - reasoning_effort: instant | low | medium | high (Mercury 3
    defaults to low); max_completion_tokens default 24,576 for
    mercury-3.

Mercury comes from Inception Labs ONLY, never from Experimental Labs
(user's correction, 2026-11-24). The key is an Inception Mercury key
(7 exist in the Oracle1 panel vault, verified working 2026-11-18).

IMPORTANT — Mercury sunset: Inception's docs state the Mercury API is
winding down and remains fully available only through December 28,
2026; after that date there is no access to the service. This DOES
govern this tool (it calls Inception directly). The client takes
base_url/model from config precisely so the same pipeline can point at
another OpenAI-compatible endpoint with one setting change after the
sunset. See README.md.

The API key comes ONLY from the environment (MERCURY_API_KEY). It is
never read from a file, never logged, and never appears in output.
This sandbox does not hold the key and must never try to fetch it
from the vault — the live test runs in the main chat, which holds the
vault key (see README.md).
"""

from __future__ import annotations

import json
import os
import time
import urllib.error
import urllib.request

DEFAULT_BASE_URL = "https://api.inceptionlabs.ai/v1"
DEFAULT_MODEL = "mercury-3"
DEFAULT_REASONING_EFFORT = "low"
DEFAULT_MAX_TOKENS = 1024
DEFAULT_TIMEOUT_SECONDS = 120
MAX_RETRIES = 5
BACKOFF_BASE_SECONDS = 1.0


class MercuryError(Exception):
    """Raised for non-retryable Mercury failures (bad key, no credits)."""


class MercuryRateLimited(Exception):
    """Raised when retries are exhausted on 429/5xx responses."""


class MercuryClient:
    """Thin client for POST /v1/chat/completions."""

    def __init__(self, api_key=None, base_url=None, model=None,
                 reasoning_effort=None, max_tokens=None,
                 timeout_seconds=DEFAULT_TIMEOUT_SECONDS):
        self.api_key = api_key or os.environ.get("MERCURY_API_KEY")
        if not self.api_key:
            raise MercuryError(
                "MERCURY_API_KEY is not set. Export it before running "
                "(see .env.example). The key is never stored in this repo.")
        self.base_url = (base_url or os.environ.get("MERCURY_BASE_URL")
                         or DEFAULT_BASE_URL).rstrip("/")
        self.model = model or os.environ.get("MERCURY_MODEL") or DEFAULT_MODEL
        self.reasoning_effort = (reasoning_effort
                                 or os.environ.get("MERCURY_REASONING_EFFORT")
                                 or DEFAULT_REASONING_EFFORT)
        self.max_tokens = max_tokens or DEFAULT_MAX_TOKENS
        self.timeout_seconds = timeout_seconds

    def chat(self, messages, temperature=0.0):
        """Send one chat-completions request; return the assistant text.

        Retries 429 (rate limit) and 5xx with exponential backoff,
        honouring Retry-After when the server sends one. 401 (bad key)
        and 402 (out of credits) fail immediately — retrying them
        cannot help.
        """
        payload = {
            "model": self.model,
            "messages": messages,
            "temperature": temperature,
            "max_completion_tokens": self.max_tokens,
            "reasoning_effort": self.reasoning_effort,
        }
        body = json.dumps(payload).encode("utf-8")
        request = urllib.request.Request(
            self.base_url + "/chat/completions",
            data=body,
            headers={
                "Authorization": "Bearer " + self.api_key,
                "Content-Type": "application/json",
            },
            method="POST",
        )
        last_error = None
        for attempt in range(MAX_RETRIES + 1):
            try:
                with urllib.request.urlopen(
                        request, timeout=self.timeout_seconds) as response:
                    data = json.loads(response.read().decode("utf-8"))
                return data["choices"][0]["message"]["content"]
            except urllib.error.HTTPError as exc:
                detail = _read_error_body(exc)
                if exc.code == 401:
                    raise MercuryError(
                        "Mercury rejected the API key (HTTP 401). "
                        "Check MERCURY_API_KEY. Server said: %s" % detail)
                if exc.code == 402:
                    raise MercuryError(
                        "Mercury reports out of credits/quota (HTTP 402). "
                        "Server said: %s" % detail)
                if exc.code in (429, 500, 502, 503, 504):
                    last_error = exc
                    if attempt == MAX_RETRIES:
                        break
                    wait = _backoff_seconds(attempt, exc)
                    time.sleep(wait)
                    continue
                raise MercuryError(
                    "Mercury request failed (HTTP %d): %s"
                    % (exc.code, detail))
            except urllib.error.URLError as exc:
                last_error = exc
                if attempt == MAX_RETRIES:
                    break
                time.sleep(_backoff_seconds(attempt, None))
        raise MercuryRateLimited(
            "Mercury request failed after %d retries: %s"
            % (MAX_RETRIES, last_error))

    def ping(self):
        """Check the key against GET /v1/models. Returns True/False."""
        request = urllib.request.Request(
            self.base_url + "/models",
            headers={"Authorization": "Bearer " + self.api_key},
            method="GET",
        )
        try:
            with urllib.request.urlopen(
                    request, timeout=30) as response:
                data = json.loads(response.read().decode("utf-8"))
            return any(m.get("id") == self.model
                       for m in data.get("data", []))
        except Exception:
            return False


def _read_error_body(exc):
    try:
        return exc.read().decode("utf-8", "replace")[:500]
    except Exception:
        return ""


def _backoff_seconds(attempt, exc):
    """Exponential backoff (1, 2, 4, 8, 16 s), honouring Retry-After."""
    if exc is not None:
        retry_after = exc.headers.get("Retry-After") if exc.headers else None
        if retry_after:
            try:
                return max(1.0, float(retry_after))
            except ValueError:
                pass
    return BACKOFF_BASE_SECONDS * (2 ** attempt)
