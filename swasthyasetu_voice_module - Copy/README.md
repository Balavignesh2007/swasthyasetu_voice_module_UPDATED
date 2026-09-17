# SwasthyaSetu — Voice-Based Healthcare Access & Emergency ASHA Alert Module

A FastAPI backend implementing the voice/IVR healthcare access layer described
in the master implementation prompt: patients on a basic phone call a
helpline, speak their symptoms, get triaged, and — critically — get an
immediate ASHA (community health worker) alert if a clinical red flag is
detected, bypassing the ML triage model entirely.

> **Core principle (unchanged from spec):** this is a healthcare
> decision-support and access system. It does not replace doctors and never
> issues a definitive diagnosis to the patient.

## Architecture

```
Patient (basic phone)
   → Twilio Programmable Voice
   → FastAPI webhook (/api/v1/voice/incoming)
   → IVR (language → identification → main menu)
   → Speech captured (Twilio speech-to-text fast path)
   → Translation (OpenAI) → Clinical Normalization → Clinical NER
   → Emergency Red-Flag Safety Layer
        ├─ EMERGENCY → ASHA Alert + emergency instructions (skips ML triage)
        └─ NOT emergency → XGBoost → LOW / HIGH
   → Speciality recommendation → Sentence-Transformer facility matching
   → Appointment / Referral → Patient record
```

Full service-layer breakdown lives in `backend/app/services/`, one file per
service named to match the spec's `BACKEND SERVICE ARCHITECTURE` section
(`TwilioService`, `CallSessionService`, `PatientIdentityService`,
`SpeechService`, `LanguageService`, `TranslationService`,
`NormalizationService` + `ClinicalNLPService` (MultiClinNER integration
point), `EmergencySafetyService`, `TriageMLService` (XGBoost),
`SpecialityService`, `SemanticMatchingService` (sentence-transformers),
`AppointmentService`, `ReferralService`, `AshaAlertService`,
`NotificationService`, `AuditService`).

## What's real vs. what you must supply

This is production-shaped, not a mock:

- **Twilio**: real TwiML generation and webhook-signature validation
  (`app/services/twilio_service.py`, `app/utils/security.py`). You supply a
  Twilio account, a voice-enabled number, and a public HTTPS URL.
- **Whisper**: real OpenAI Whisper API calls for transcription
  (`app/services/speech_service.py`). You supply `OPENAI_API_KEY`.
- **Translation**: real OpenAI chat-completion calls with a constrained,
  no-invention prompt (`app/services/translation_service.py`).
- **XGBoost triage model**: a real, trained model — `ml/xgboost/train_triage_model.py`
  trains it. It ships with a **synthetic** dataset so the system runs
  end-to-end out of the box; replace the dataset with real, clinically
  labeled data before production use.
- **Sentence-transformer facility matching**: real embeddings, built by
  `ml/sentence_transformers/build_facility_embeddings.py` from your actual
  facilities table.
- **Clinical NER ("MultiClinNER")**: a real integration point for a
  HuggingFace token-classification model, with a transparent, auditable
  lexicon fallback so the pipeline never silently does nothing. See
  `ml/multiclinner/README.md` — **this is the piece most in need of your
  organization's own trained/validated model before production use**, and it
  currently does not handle negation ("no chest pain") — read that README's
  caveat before relying on it for unattended emergency screening.
- **Emergency red-flag rules**: intentionally rule-based (not ML) for
  auditability, but the exact rule list in `app/services/emergency_service.py`
  is a **starting point that must be clinically reviewed and signed off**
  before production, exactly as the spec requires.

## Setup

```bash
cd backend
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # fill in TWILIO_*, OPENAI_API_KEY, JWT_SECRET, PHONE_HASH_SALT, etc.

# Train the triage model (synthetic data by default — see ml/xgboost/train_triage_model.py)
python ml/xgboost/train_triage_model.py

# Start the API (creates tables on startup)
uvicorn app.main:app --reload

# In another shell: seed demo facilities/ASHA worker/patient
python scripts/seed_demo_data.py

# Build facility embeddings for semantic matching (after seeding facilities)
python ml/sentence_transformers/build_facility_embeddings.py
```

Point your Twilio phone number's "A call comes in" webhook at:
```
https://<your-public-url>/api/v1/voice/incoming   (HTTP POST)
```
Use a tunnel (e.g. ngrok) for local development, and set `PUBLIC_BASE_URL` in
`.env` to match exactly — it's used both to build the next-step webhook URLs
in TwiML and to validate Twilio's request signature.

### Run tests
```bash
cd backend
pytest tests/ -v
```
The included tests cover the emergency red-flag safety layer, since it's the
single most safety-critical piece of the pipeline.

### Docker
```bash
cd backend
docker compose up --build
```

## Security notes

- Caller phone numbers are **never stored in plaintext** for lookups — only
  an HMAC-SHA256 hash (`app/utils/security.py`), salted with
  `PHONE_HASH_SALT`. A phone number alone is never treated as sufficient
  identity proof for exposing patient data (spec section 4) — health ID
  verification is required.
- Twilio webhook signatures are validated on every inbound webhook
  (`validate_twilio_signature`), skipped only when no `TWILIO_AUTH_TOKEN` is
  configured (local dev).
- ASHA alerts send **only the minimum information required** (patient ID,
  severity, red flag type, call time) — never the full transcript.
- No secrets are hard-coded; everything comes from `.env` / environment
  variables (`app/config.py`).
- `CALL_RECORDING_ENABLED` defaults to `false`, per spec section 38 — do not
  enable recording without an established consent/legal basis and a
  retention/deletion policy.

## Frontends

Four Flutter clients connect to this backend, matching the spec's unified
architecture (section 51):

| App | Path | Purpose |
|---|---|---|
| ASHA worker app | `asha_app/` | Receive/acknowledge/resolve emergency alerts, view assigned patients |
| Patient app | `mobile/` | View appointments, referrals, call history; one-tap call to the helpline |
| Admin dashboard | `dashboard/` | Flutter web — call volume, alert, referral/appointment observability, and (admin role only) doctor account management |
| Doctor app | `doctor_app/` | Flutter mobile — same JWT login as the dashboard; read-only overview/alerts/referrals for doctors on the go |

Each has its own README with setup steps and the specific backend endpoints
it depends on. All four talk to this backend over plain REST (no push
notifications yet — see each README's "Known gaps" section).

## Known gaps to close before production

1. **Clinical NER negation handling** — see `ml/multiclinner/README.md`.
2. **Red-flag rule list clinical sign-off** — see `app/services/emergency_service.py`.
3. **Real triage training data** — replace the synthetic dataset in
   `ml/xgboost/train_triage_model.py`.
4. **DTMF fallback menus** for symptom collection when speech fails
   repeatedly (spec section 35) — currently only retries speech capture;
   extend `_handle_symptom_collection` in `app/api/voice.py` with a numbered
   keypad symptom menu.
5. **India emergency-service routing (112)** — per the spec, do NOT route
   Indian emergency calls through Twilio if Twilio doesn't support that
   pathway in your deployment region; the ASHA-alert flow here is the
   community-health-worker notification path, not a 112 integration.
6. **Offline-first ASHA app sync queue** (spec section 39) — not included;
   this repo covers the backend voice/alert API the ASHA app would sync
   against.
