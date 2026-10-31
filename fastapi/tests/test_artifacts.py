"""A changed model file must never be loaded as a trusted artifact."""

import shutil
from pathlib import Path

import pytest

from kankal_ml import models


def test_tampered_artifact_is_rejected(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    shutil.copytree(models.ASSETS / "data", tmp_path / "data")
    shutil.copytree(models.ASSETS / "models", tmp_path / "models")
    artifact = tmp_path / "models/search.skops"
    artifact.write_bytes(artifact.read_bytes() + b"changed")
    monkeypatch.setattr(models, "ASSETS", tmp_path)

    with pytest.raises(RuntimeError, match="verification failed"):
        models.ModelBundle()
