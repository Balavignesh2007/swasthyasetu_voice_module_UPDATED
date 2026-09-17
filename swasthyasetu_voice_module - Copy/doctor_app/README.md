# SwasthyaSetu Doctor App (Flutter, mobile)

A standalone mobile app for doctors/staff, scaffolded against the same
`/api/v1/auth/*` JWT login used by the web dashboard (`dashboard/`) — so any
active `doctor_users` account works in either app interchangeably. This
exists alongside `dashboard/` (desktop/web-oriented, `NavigationRail`) and
`asha_app/` (ASHA worker, phone-lookup login) as the third client of the
same backend.

## Screens
- **Login** — username + password via `POST /api/v1/auth/login` (JWT bearer token), same credentials as the dashboard
- **Overview** — 2-column stat-card grid backed by `GET /api/v1/admin/dashboard`, auto-refreshes every 20s
- **Alerts** — emergency-event list (pull to refresh) via `GET /api/v1/admin/emergency-events`
- **Referrals & Appointments** — tabbed lists via `GET /api/v1/admin/referrals` and `GET /api/v1/admin/appointments`

All of these endpoints require a valid `Authorization: Bearer <token>`
header (see `app/api/auth.py` / `app/utils/security.py` in the backend, and
`get_current_doctor`). `ApiService` attaches the token automatically once
logged in, and `SessionService` caches it locally so an app restart doesn't
log you out. Any `doctor` or `admin` role account can use this app — the
admin-only doctor-account-management screen lives in `dashboard/` only (see
its README), not here.

### Test login

After seeding demo data on the backend (`python scripts/seed_demo_data.py`),
log in with username `dr.sharma` and password `doctor123` (or `admin` /
`admin12345` for an admin account — the doctor-app screens work the same
for both roles, since none of them are admin-gated).

## Setup

```bash
cd doctor_app
flutter create --project-name swasthyasetu_doctor_app --platforms android,ios .
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

For a release build:
```bash
flutter build apk --dart-define=API_BASE_URL=https://your-backend-domain.example.com
# or: flutter build ios --dart-define=API_BASE_URL=https://your-backend-domain.example.com
```

`API_BASE_URL` defaults to `http://localhost:8000` (see `lib/config.dart`)
— on a physical device or emulator that can't resolve `localhost` as your
dev machine, pass your machine's LAN IP or `10.0.2.2` (Android emulator)
instead.

## Known gaps / next steps
1. **No push notifications** — unlike a real on-call doctor app, there's no
   FCM/APNs wiring for new emergency alerts; doctors have to have the app
   open (or pull to refresh) to see new ones. `asha_app` has the same gap.
2. **Read-only** — this app only *views* alerts/referrals/appointments; it
   doesn't yet let a doctor acknowledge an alert, update a referral, or close
   out an appointment from their phone (`asha_app`'s alert-status endpoints
   are ASHA-worker-scoped, not doctor-scoped, so this would need new backend
   endpoints, not just new screens).
3. **Single dashboard payload** — like the web dashboard, `GET
   /api/v1/admin/dashboard` returns a fixed set of counters; no per-doctor
   filtering (e.g. "my facility only") yet.
