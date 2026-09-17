# SwasthyaSetu Admin Dashboard (Flutter Web)

Observability dashboard for facility/program administrators — call volume,
emergency alerts, HIGH/LOW triage split, referrals, and appointments (spec
sections 41/42).

## Screens
- **Login** — doctor username + password, via `POST /api/v1/auth/login` (JWT bearer token)
- **Overview** — stat-card grid backed by `GET /api/v1/admin/dashboard`, auto-refreshes every 20s
- **Alerts** — full emergency-event table via `GET /api/v1/admin/emergency-events`
- **Referrals & Appointments** — tabbed tables via `GET /api/v1/admin/referrals` and `GET /api/v1/admin/appointments`
- **Manage Doctors** *(admin role only)* — create/list/deactivate doctor_users
  accounts via `GET`/`POST /api/v1/admin/doctors` and `PATCH
  /api/v1/admin/doctors/{id}/status`. Hidden from the nav for non-admin
  doctors; the backend also rejects non-admins with a 403 independently, so
  hiding the tab is a UI convenience, not the security boundary.

All `/api/v1/admin/*` endpoints and `GET /api/v1/auth/me` now require a
valid `Authorization: Bearer <token>` header — see `app/api/auth.py` and
`app/utils/security.py` in the backend. The dashboard's `ApiService`
attaches this automatically once you're logged in, and `SessionService`
caches the token locally so a refresh doesn't log you out.

### Test login

After seeding demo data on the backend (`python scripts/seed_demo_data.py`),
log in with username `dr.sharma` and password `doctor123`.

## Setup

```bash
cd dashboard
flutter create --project-name swasthyasetu_admin_dashboard --platforms web .
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
```

For a production build:
```bash
flutter build web --dart-define=API_BASE_URL=https://your-backend-domain.example.com
# serve build/web/ behind your web server / static hosting of choice
```

## Layout notes

Uses a `NavigationRail` on wide screens (≥800px) and falls back to a bottom
`NavigationBar` on narrow ones, so the same codebase works reasonably as
either a desktop-width admin panel or embedded in a narrower frame.

## Known gaps / next steps
1. ~~**Password reset / user management**~~ — resolved: an admin-role
   account can now create and deactivate doctor logins from the **Manage
   Doctors** screen (`POST`/`GET /api/v1/admin/doctors`,
   `PATCH /api/v1/admin/doctors/{id}/status`). There's still no self-serve
   signup or "forgot password" flow — an admin has to issue a temporary
   password and share it out of band.
2. **CORS** — the backend's `CORSMiddleware` currently allows all origins in
   development (`app/main.py`). Restrict `allow_origins` to your deployed
   dashboard's domain before production.
3. **Filtering/search** — tables currently show the most recent 100 rows with
   no filters; add date-range and status filters as the data volume grows.
4. **Charts** — the spec's observability section also calls out trends over
   time (language distribution, speech recognition failures, etc.) which
   aren't in the current `/api/v1/admin/dashboard` payload — extend the
   backend endpoint and add a charting package (e.g. `fl_chart`) if needed.

## Related: standalone doctor mobile app

`../doctor_app/` is a separate Flutter project (phone-oriented, bottom nav)
scaffolded against the same `/api/v1/auth/*` login as this dashboard — see
its README. It's read-only (overview/alerts/referrals) and doesn't include
the Manage Doctors screen; that stays dashboard-only for now.
