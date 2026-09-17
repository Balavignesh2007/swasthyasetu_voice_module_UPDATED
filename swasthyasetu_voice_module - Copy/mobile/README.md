# SwasthyaSetu Patient App (Flutter)

The smartphone-app frontend for patients with a data connection — a
lighter-weight companion to the voice helpline (which remains the primary
access path for basic-phone users with no smartphone/internet).

## Screens
- **Login** — phone number + health ID (same two-factor identity check as the voice IVR)
- **Home** — welcome, prominent "Call Helpline" action (uses the device dialer), quick links
- **Appointments** — list of booked appointments with status and queue number
- **Referrals** — referral list with a visual Created → Accepted → In Progress → Completed stepper
- **Call History** — past voice-helpline interactions (transcripts, language, timestamps)

## Backend endpoints used
| Screen | Endpoint |
|---|---|
| Login | `GET /api/v1/patients/login?caller_phone=...&health_id=...` |
| Home/profile | `GET /api/v1/patients/{id}` |
| Appointments | `GET /api/v1/patients/{id}/appointments` |
| Referrals | `GET /api/v1/patients/{id}/referrals` |
| Call History | `GET /api/v1/patients/{id}/voice-history` |

These were added to `backend/app/api/patients.py` (`patient_router`) alongside
this app — make sure your backend is up to date.

## Setup

```bash
cd mobile
flutter create --project-name swasthyasetu_patient_app .
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

See `asha_app/README.md` for the same platform-specific notes on choosing
`API_BASE_URL` (emulator vs. simulator vs. physical device vs. production).

### Test login

After seeding demo data on the backend (`python scripts/seed_demo_data.py`),
log in with phone `+919000000001` and health ID `HID10001`.

### Helpline number

`lib/config.dart` has a placeholder `helplineNumber` — set it to your actual
provisioned Twilio number so the "Call Helpline" button dials the real IVR.

## Known gaps / next steps
1. **Real authentication** — same caveat as the ASHA app: phone+health-ID
   lookup only, no JWT session yet.
2. **Booking/rescheduling from the app** — currently read-only; wire up
   `POST /api/v1/voice/appointment` and referral creation endpoints for a
   full booking flow if patients should be able to self-serve beyond viewing.
3. **Push notifications** for appointment reminders / referral status changes.
4. **Multilingual UI** — the voice IVR supports multiple languages; this app's
   UI strings are English-only. Add `flutter_localizations` + ARB files using
   `preferred_language` from the patient profile to pick the locale.
