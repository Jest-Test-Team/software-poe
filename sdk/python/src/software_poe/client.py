from typing import Any

import httpx

from .models import Event


class Client:
    """Client for the Software POE gateway API."""

    def __init__(self, base_url: str, api_key: str | None = None, timeout: float = 10.0):
        headers = {"X-API-Key": api_key} if api_key else {}
        self._http = httpx.Client(base_url=base_url, headers=headers, timeout=timeout)

    def ingest(self, event: Event) -> dict[str, Any]:
        event.validate()
        resp = self._http.post("/v1/software-poe/events", json=event.to_dict())
        resp.raise_for_status()
        return resp.json()

    def assessments(self, tenant_id: str, status: str | None = None) -> list[dict[str, Any]]:
        params: dict[str, str] = {"tenant_id": tenant_id}
        if status:
            params["status"] = status
        resp = self._http.get("/v1/software-poe/assessments", params=params)
        resp.raise_for_status()
        return resp.json()

    def review(
        self,
        assessment_id: str,
        tenant_id: str,
        reviewer: str,
        decision: str,
        annotation: str | None = None,
    ) -> dict[str, Any]:
        resp = self._http.post(
            f"/v1/software-poe/assessments/{assessment_id}/review",
            params={"tenant_id": tenant_id},
            json={"reviewer": reviewer, "decision": decision, "annotation": annotation},
        )
        resp.raise_for_status()
        return resp.json()

    def close(self) -> None:
        self._http.close()

    def __enter__(self) -> "Client":
        return self

    def __exit__(self, *exc: object) -> None:
        self.close()
