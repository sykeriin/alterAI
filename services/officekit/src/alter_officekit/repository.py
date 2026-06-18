from __future__ import annotations

from collections import defaultdict
from typing import Protocol
from uuid import UUID

from .schemas import OfficeArtifact, OfficeArtifactCreate


class OfficeKitRepository(Protocol):
    def create_artifact(self, payload: OfficeArtifactCreate) -> OfficeArtifact:
        ...

    def get_artifacts(self, user_id: UUID, artifact_ids: list[UUID]) -> list[OfficeArtifact]:
        ...


class InMemoryOfficeKitRepository:
    def __init__(self) -> None:
        self._artifacts: dict[UUID, list[OfficeArtifact]] = defaultdict(list)

    def create_artifact(self, payload: OfficeArtifactCreate) -> OfficeArtifact:
        artifact = OfficeArtifact(**payload.model_dump())
        self._artifacts[artifact.user_id].append(artifact)
        return artifact

    def get_artifacts(self, user_id: UUID, artifact_ids: list[UUID]) -> list[OfficeArtifact]:
        artifacts = self._artifacts.get(user_id, [])
        if not artifact_ids:
            return list(artifacts)
        wanted = set(artifact_ids)
        return [artifact for artifact in artifacts if artifact.id in wanted]
