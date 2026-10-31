"""Read-only, verified demonstration models and inference operations."""

import hashlib
import json
from pathlib import Path
from typing import Any

import numpy as np
import skops.io as sio
from sklearn.metrics.pairwise import cosine_similarity

ASSETS = Path(__file__).resolve().parent


class ModelBundle:
    def __init__(self) -> None:
        self.data: dict[str, Any] = json.loads((ASSETS / "data/demo.json").read_text())
        manifest = json.loads((ASSETS / "models/manifest.json").read_text())
        self.version: str = manifest["version"]
        self.models: dict[str, Any] = {}
        for name, details in manifest["models"].items():
            path = ASSETS / "models" / f"{name}.skops"
            if hashlib.sha256(path.read_bytes()).hexdigest() != details["sha256"]:
                raise RuntimeError("Model artifact verification failed")
            self.models[name] = sio.load(path, trusted=details["trusted_types"])

        self.docs = self.data["documents"]
        self.tickets = self.data["tickets"]
        self.products = self.data["products"]
        self.doc_vectors = self.models["search"].transform(
            [row["text"] for row in self.docs]
        )
        self.ticket_vectors = self.models["duplicates"].transform(
            [row["text"] for row in self.tickets]
        )
        self.product_vectors = self.models["recommendations"].transform(
            [row["text"] for row in self.products]
        )
        self.topic_names: dict[int, str] = {}
        for row in self.docs:
            topic = int(self.models["topics"].predict([row["text"]])[0])
            self.topic_names.setdefault(topic, row["topic"])

    @staticmethod
    def _matches(
        scores: np.ndarray, limit: int, threshold: float = 0.0
    ) -> list[tuple[int, float]]:
        return [
            (int(i), float(scores[i]))
            for i in np.argsort(scores)[::-1]
            if float(scores[i]) > threshold
        ][:limit]

    def search(self, query: str, limit: int) -> list[dict[str, Any]]:
        scores = cosine_similarity(
            self.models["search"].transform([query]), self.doc_vectors
        )[0]
        return [
            {
                "document_id": self.docs[i]["id"],
                "text": self.docs[i]["text"],
                "score": score,
            }
            for i, score in self._matches(scores, limit)
        ]

    def tag(self, text: str) -> dict[str, Any]:
        model = self.models["tagging"]
        if model[0].transform([text]).nnz == 0:
            return {"label": "unknown", "score": 0.0}
        probabilities = model.predict_proba([text])[0]
        index = int(np.argmax(probabilities))
        return {
            "label": str(model.classes_[index]),
            "score": float(probabilities[index]),
        }

    def keyphrases(self, text: str, limit: int) -> list[dict[str, Any]]:
        vectorizer = self.models["phrases"]
        scores = vectorizer.transform([text]).toarray()[0]
        terms = vectorizer.get_feature_names_out()
        return [
            {"phrase": str(terms[i]), "score": score}
            for i, score in self._matches(scores, limit)
        ]

    def topic(self, text: str) -> dict[str, Any]:
        if self.models["topics"][0].transform([text]).nnz == 0:
            return {"group": -1, "sample_topic": "unknown"}
        group = int(self.models["topics"].predict([text])[0])
        return {"group": group, "sample_topic": self.topic_names[group]}

    def duplicates(self, text: str, limit: int) -> list[dict[str, Any]]:
        scores = cosine_similarity(
            self.models["duplicates"].transform([text]), self.ticket_vectors
        )[0]
        return [
            {"ticket_id": f"ticket-{i + 1}", "score": score}
            for i, score in self._matches(scores, limit, 0.2)
        ]

    def recommendations(self, item_id: str, limit: int) -> list[dict[str, Any]] | None:
        index = next(
            (i for i, item in enumerate(self.products) if item["id"] == item_id), None
        )
        if index is None:
            return None
        scores = cosine_similarity(self.product_vectors[index], self.product_vectors)[0]
        scores[index] = 0
        return [
            {"item_id": self.products[i]["id"], "score": score}
            for i, score in self._matches(scores, limit)
        ]

    def anomaly(self, temperature: float, vibration: float) -> dict[str, Any]:
        features = [[temperature, vibration]]
        model = self.models["anomaly"]
        return {
            "anomaly": bool(model.predict(features)[0] == -1),
            "score": float(model.decision_function(features)[0]),
        }

    def risk(self, age: float, temperature: float) -> dict[str, Any]:
        probability = float(
            self.models["risk"].predict_proba([[age, temperature]])[0][1]
        )
        return {"risk": probability, "flagged": probability >= 0.5}

    def price(self, quantity: float, grade: float) -> dict[str, Any]:
        value = float(self.models["price"].predict([[quantity, grade]])[0])
        return {"estimated_value": value}

    def forecast(self, series_id: str, horizon: int) -> list[float] | None:
        values = self.data["demand"].get(series_id)
        if values is None:
            return None
        days = np.arange(len(values), len(values) + horizon).reshape(-1, 1)
        return [
            max(0.0, float(value))
            for value in self.models[f"forecast_{series_id}"].predict(days)
        ]
