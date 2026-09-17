# SwasthyaSetu Voice Triage Pipeline

## Final architecture

Any supported language voice -> Speech-to-Text -> Translation to English -> Clinical Normalization -> MultiClinNER -> XGBoost -> Triage -> Recommendation / Referral.

### Triage outputs
- EMERGENCY: immediate emergency referral.
- URGENT: prompt/same-day medical evaluation.
- ROUTINE: routine outpatient consultation.

The XGBoost model keeps its existing internal class labels (`EMERGENCY`, `HIGH_RISK`, `LOW_RISK`) for artifact compatibility, while the public API maps them to `EMERGENCY`, `URGENT`, and `ROUTINE`. Danger-sign safety rules remain an override for immediate emergency cases.

### APIs
- `POST /api/v1/clinical/process-voice` accepts a transcript and runs the clinical pipeline.
- `POST /api/v1/clinical/process-voice-audio` accepts an audio upload, performs Speech-to-Text, then runs the same pipeline.
