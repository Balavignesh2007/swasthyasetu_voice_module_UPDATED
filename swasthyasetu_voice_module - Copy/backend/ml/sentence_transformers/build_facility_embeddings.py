"""
Precomputes sentence-transformer embeddings for every facility's service
description, so SemanticMatchingService can do a fast cosine-similarity
lookup at call time instead of embedding every facility on every request.

Run this whenever facilities/services change:
    cd backend
    python ml/sentence_transformers/build_facility_embeddings.py
"""
import pickle
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))  # backend/ on path

from sentence_transformers import SentenceTransformer  # noqa: E402

from app.config import settings  # noqa: E402
from app.database.database import SessionLocal  # noqa: E402
from app.models.models import Facility  # noqa: E402


def main():
    model = SentenceTransformer(settings.SENTENCE_TRANSFORMER_MODEL)
    db = SessionLocal()
    try:
        facilities = db.query(Facility).all()
        if not facilities:
            print("No facilities found in the database — add facilities before running this script.")
            return

        texts = [
            f"{f.name}. Type: {f.facility_type or ''}. "
            f"Specialities: {f.specialities or ''}. {f.services_description or ''}"
            for f in facilities
        ]
        embeddings = model.encode(texts, convert_to_numpy=True, show_progress_bar=True)

        payload = {
            "facility_ids": [f.id for f in facilities],
            "embeddings": embeddings,
        }
        output_path = Path(__file__).parent / "facility_embeddings.pkl"
        with open(output_path, "wb") as f:
            pickle.dump(payload, f)

        print(f"Saved {len(facilities)} facility embeddings to {output_path}")
    finally:
        db.close()


if __name__ == "__main__":
    main()
