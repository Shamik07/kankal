"""Build the small, versioned demonstration model bundle from synthetic data."""

import hashlib
import json
from pathlib import Path

import numpy as np
import skops.io as sio
from sklearn.cluster import KMeans
from sklearn.ensemble import IsolationForest, RandomForestRegressor
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LinearRegression, LogisticRegression
from sklearn.pipeline import make_pipeline

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "src/kankal_ml"
DATA = json.loads((ASSETS / "data/demo.json").read_text())
OUT = ASSETS / "models"


def save(name: str, model: object, manifest: dict[str, object]) -> None:
    path = OUT / f"{name}.skops"
    sio.dump(model, path)
    manifest[name] = {
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "trusted_types": sorted(sio.get_untrusted_types(file=path)),
    }


def main() -> None:
    OUT.mkdir(exist_ok=True)
    models: dict[str, object] = {}
    manifest: dict[str, object] = {"version": "demo-1", "models": models}

    docs = [row["text"] for row in DATA["documents"]]
    tickets = [row["text"] for row in DATA["tickets"]]
    ticket_labels = [row["label"] for row in DATA["tickets"]]
    products = [row["text"] for row in DATA["products"]]

    search = TfidfVectorizer(ngram_range=(1, 2), stop_words="english").fit(docs)
    save("search", search, models)
    tagging = make_pipeline(
        TfidfVectorizer(ngram_range=(1, 2)),
        LogisticRegression(max_iter=500, random_state=7),
    ).fit(tickets, ticket_labels)
    save("tagging", tagging, models)
    phrases = TfidfVectorizer(ngram_range=(1, 2), stop_words="english").fit(
        docs + tickets
    )
    save("phrases", phrases, models)
    topics = make_pipeline(
        TfidfVectorizer(stop_words="english"),
        KMeans(n_clusters=3, random_state=7, n_init=10),
    ).fit(docs)
    save("topics", topics, models)
    duplicates = TfidfVectorizer(ngram_range=(1, 2)).fit(tickets)
    save("duplicates", duplicates, models)
    recommendations = TfidfVectorizer(stop_words="english").fit(products)
    save("recommendations", recommendations, models)
    anomaly = IsolationForest(random_state=7, contamination=0.1).fit(
        np.array(DATA["sensor_training"])
    )
    save("anomaly", anomaly, models)
    risk = LogisticRegression(max_iter=500, random_state=7).fit(
        [row["features"] for row in DATA["risk_training"]],
        [row["label"] for row in DATA["risk_training"]],
    )
    save("risk", risk, models)
    price = RandomForestRegressor(n_estimators=30, random_state=7).fit(
        [row["features"] for row in DATA["price_training"]],
        [row["value"] for row in DATA["price_training"]],
    )
    save("price", price, models)
    for name, values in DATA["demand"].items():
        forecast = LinearRegression().fit(np.arange(len(values)).reshape(-1, 1), values)
        save(f"forecast_{name}", forecast, models)

    (OUT / "manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n"
    )


if __name__ == "__main__":
    main()
