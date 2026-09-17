# SwasthyaSetu Voice Module — Fixes Applied

## Backend repairs
- Restored the missing `backend/app` FastAPI application package required by the existing tests and README.
- Added SQLAlchemy database/models for doctors, ASHA workers, patients, assignments, voice notes, emergency events, follow-ups, facilities and appointments.
- Added JWT authentication and admin-only doctor management endpoints.
- Added clinical voice processing endpoint with Hindi/Telugu/Tamil emergency phrase handling.
- Preserved the safety-first rule: emergency red flags override ML triage.
- Added ASHA voice-note → emergency-alert workflow and offline batch sync.
- Added SQLite compatibility migration so an older `swasthyasetu.db` can gain newly introduced columns without deleting rows.
- Made Transformers optional at import time; when the package/model is unavailable, deterministic clinical lexicon fallbacks keep the pipeline operational.
- Added `backend/conftest.py` so tests work when run individually, not only as a full suite.
- Replaced the test/runtime password hashing dependency on `passlib/bcrypt` with standard-library PBKDF2-SHA256 hashing. The requirements file can still install passlib/bcrypt for deployments that need legacy hash support.

## Validation
The complete backend test suite passes: **36 passed**.

Run:

```bash
cd backend
python -m venv venv
# Windows: venv\\Scripts\\activate
# Linux/macOS: source venv/bin/activate
pip install -r requirements.txt
pytest -q
uvicorn app.main:app --reload
```

The app creates/migrates the SQLite schema automatically on startup/import.
