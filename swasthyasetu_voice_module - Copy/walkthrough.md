# SwasthyaSetu Unified Healthcare Portal — Walkthrough

## Summary of Completed Work

We have successfully consolidated the separate portal hosts into **ONE SINGLE FLUTTER HOST** (`http://localhost:8080`) built **100% in pure Flutter widgets** without any HTML or CSS files. Anyone can log in according to their roles or switch between roles dynamically.

---

## 1. Unified Single Host Architecture

- **Host URL**: `http://localhost:8080`
- **Backend API**: `http://localhost:8000/api/v1`
- **Tech Stack**: 100% Flutter Web (Dart) — No external HTML/CSS files.

### Seeded Demo Accounts (1-Click Login Enabled):
1. **Doctor / Specialist**:
   - **Username**: `dr.sharma` | **Password**: `doctor123`
   - *One-Click Demo Button available on login screen*
2. **ASHA Worker**:
   - **Phone**: `9876543210`
   - *One-Click Demo Button available on login screen*
3. **Patient**:
   - **Phone**: `+919000000001` | **ABHA Health ID**: `HID10001`
   - *One-Click Demo Button available on login screen*

---

## 2. Key Features Across All 3 Roles in the Unified Host

### Role 1: Doctor / Specialist Portal
- **OPD Appointments & Voice Triage Queue**:
  - Displays all booked appointments created by ASHA voice notes or patient interactions.
  - Shows assigned queue numbers (`#1`, `#2`, etc.) and clinical specialty (`Cardiology`, `Pulmonology`, `Gastroenterology`, `General Medicine`).
  - Displays full **patient voice details**: raw transcript, English translation, extracted symptoms, and emergency red-flag badges.
- **Doctor Prescription & Diagnosis Writer**:
  - Doctors can click **"Add Prescription"** to enter diagnosis, medications, and advice.
  - Saves to database (`POST /api/v1/admin/appointments/{id}/prescribe`) and displays directly on both the doctor queue and patient portal.
- **Patient Referral Manager**:
  - Doctors can refer patients to higher facilities (District Hospitals, Medical Colleges) with urgency tags (`EMERGENCY`, `URGENT`, `ROUTINE`).
- **Emergency Red Flag Alerts**:
  - Live monitoring of high-risk triage alerts.
- **Clinical Telemetry & Analytics**:
  - Real-time KPI cards for voice calls, alerts, triage distribution, and referral rates.

---

### Role 2: ASHA Worker Portal
# Walkthrough - SwasthyaSetu Real-Time ASHA Flow & Patient Registration

## Overview
Registered specific patient phone numbers and rectified the real-time IVR-to-ASHA dashboard workflow so that every incoming voice call from verified patients updates the ASHA worker portal instantly.

---

## 1. Phone Number Storage & VIP Patient Recognition
Stored and verified the requested patient records in [swasthyasetu.db](file:///c:/Users/balas/Project/swasthyasetu_voice_module_UPDATED/swasthyasetu_voice_module%20-%20Copy/backend/swasthyasetu.db):

| Phone Number | Patient Name | Health ID | Assigned ASHA Worker |
| :--- | :--- | :--- | :--- |
| **`9121458655`** | **Balavignesh** | `HID2602008` | Lakshmi Devi (`1ff3d261-76ad-4f69-9873-504b048cc67c`) |
| **`9030252566`** | **Harsha datta** | `HID903025` | Lakshmi Devi (`1ff3d261-76ad-4f69-9873-504b048cc67c`) |

### Key Improvements in [telephony_routes.py](file:///c:/Users/balas/Project/swasthyasetu_voice_module_UPDATED/swasthyasetu_voice_module%20-%20Copy/backend/src/api/telephony_routes.py):
- Added `find_patient_by_phone(db, phone_str)` to normalize and check:
  1. Direct registered phone match for `9121458655` (Balavignesh) and `9030252566` (Harsha datta).
  2. Exact E.164 phone hash (`hash_phone("+91...")`).
  3. 10-digit normalized phone hash (`hash_phone("9121458655")`).
- Personalized Greeting: When Balavignesh or Harsha datta calls, the IVR directly greets:
  - *"नमस्ते Balavignesh जी! स्वास्थ्य सेतु में आपका स्वागत है।"*
  - *"नमस्ते Harsha datta जी! स्वास्थ्य सेतु में आपका स्वागत है।"*
  and immediately prompts for symptoms without asking for ID.

---

## 2. Real-Time ASHA Dashboard Alerting Fix
### Root Causes Identified:
1. When callers spoke colloquial phrases ("हॉट पेन!" or "डिफिकल्ट टू ब्रीदिंग!"), the previous safety screen did not map transliterated phonetic strings to red flags.
2. Even when XGBoost triaged the case as `EMERGENCY`, `is_emergency` in the response remained `False` if not in canonical symptoms, bypassing the ASHA notification block.
3. If a call had non-emergency or moderate symptoms, no alert record was created at all, leaving the ASHA dashboard blank.

### Changes Made:
1. **[clinical_pipeline.py](file:///c:/Users/balas/Project/swasthyasetu_voice_module_UPDATED/swasthyasetu_voice_module%20-%20Copy/backend/src/triage/clinical_pipeline.py)**:
   - Added phonetic transliterations (`हॉट पेन`, `हार्ट पेन`, `चेस्ट पेन`, `डिफिकल्ट टू ब्रीदिंग`, `ब्रीदिंग प्रॉब्लम`, `हार्ट अटैक`) to `CLINICAL_TRANSLATION_LEXICON`.
   - Set `is_emergency = True` whenever XGBoost or safety screen flags `EMERGENCY`.
2. **[emergency_service.py](file:///c:/Users/balas/Project/swasthyasetu_voice_module_UPDATED/swasthyasetu_voice_module%20-%20Copy/backend/app/services/emergency_service.py)**:
   - Expanded red flag rules to include `heart pain`, `shortness of breath`, `breathing problem`, `heart attack`, and substring matching.
3. **[telephony_routes.py](file:///c:/Users/balas/Project/swasthyasetu_voice_module_UPDATED/swasthyasetu_voice_module%20-%20Copy/backend/src/api/telephony_routes.py)**:
   - **Guaranteed Alert Creation**: EVERY voice triage call now creates an incident in `EmergencyEvent` with appropriate severity (`HIGH`, `MEDIUM`, or `ROUTINE`).
   - **Real-Time WebSocket Broadcast**: Every call immediately triggers `websocket_manager.broadcast_emergency_alert(...)` to push live notifications to connected ASHA dashboards (`http://localhost:8080`).

---

## 3. Verification Results
- **E2E Call Simulation**:
  - `CA_BALA_001` (+919121458655): Verified as `Balavignesh`, triage classified as `Urgent Voice Triage` / `MEDIUM`, alert created and broadcast.
  - `CA_HARSHA_001` (+919030252566): Verified as `Harsha datta`, triage classified as `Acute Clinical Emergency` / `HIGH`, alert created and broadcast.
  - `/api/v1/asha/alerts`: Successfully returned both alerts with caller names and phone numbers.
- **Pytest Suite**: All 23 tests passed cleanly (100%).
- **Server Status**: FastAPI running on port 8000; Cloudflare tunnel active at `https://blink-apnic-eclipse-tyler.trycloudflare.com`.

4. **Local Web Server**:
   - `http://localhost:8080` successfully running and serving the unified Flutter web app.

---

### Role 3: Patient Portal
- **AI Voice Symptom Checker**:
  - Speak symptoms in Hindi, Telugu, Tamil, or English.
  - Instant triage guidance and emergency red-flag screening.
- **My Consultations & Prescriptions**:
  - View scheduled doctor appointments and assigned queue numbers.
  - **View Doctor's Prescription (Rx)**: Displays the doctor's written diagnosis, prescribed medications, and clinical advice.
- **Hospital Referrals**:
  - View specialist referrals recommended by the doctor.

---

### Universal Role Switcher
In the top navigation bar, users can use the **"Switch Portal"** dropdown to switch between **Doctor**, **ASHA Worker**, and **Patient** at any time.

---

## 3. Verification & Testing

1. **Flutter Analysis**:
   - `flutter analyze` executed with `0 errors`.
2. **Flutter Widget Unit Test**:
   - `flutter test` passed: `All tests passed! (Unified App smoke test)`.
3. **Backend API End-to-End Test**:
   - Tested Doctor login -> ASHA lookup -> Voice note creation -> Auto-creation of Doctor appointment -> Doctor prescription -> Patient portal viewing prescription. All steps passed with status code 200.
4. **Local Web Server**:
   - `http://localhost:8080` successfully running and serving the unified Flutter web app.

---

## 4. Code Quality Cleanup (Session 2 — `flutter analyze` lint fixes)

Started with **52 `info`-level issues**. All fixed. Final result: **0 issues**.

### Fixes Applied Across 10 Files:

| Category | Fix Applied | Files |
|---|---|---|
| `use_build_context_synchronously` | Cached `ScaffoldMessenger.of(context)` before `await`; used `dialogCtx.mounted` for dialog pops | `unified_shell.dart`, `asha_alerts_view.dart`, `asha_patients_view.dart`, `asha_voice_note_view.dart`, `admin_asha_view.dart`, `admin_doctors_view.dart`, `doctor_appointments_view.dart`, `patient_appointments_view.dart` |
| `deprecated_member_use` — `withOpacity` | Replaced `.withOpacity(x)` → `.withValues(alpha: x)` | `unified_shell.dart`, `asha_voice_note_view.dart`, `patient_voice_symptom_view.dart`, `admin_asha_view.dart`, `admin_analytics_view.dart`, `unified_login_screen.dart` |
| `deprecated_member_use` — `value:` on dropdown | Replaced `value:` → `initialValue:` on `DropdownButtonFormField` | `asha_voice_note_view.dart`, `admin_asha_view.dart`, `admin_doctors_view.dart`, `doctor_appointments_view.dart`, `patient_appointments_view.dart` |
| `deprecated_member_use` — `localeId` | Moved `localeId:` into `SpeechListenOptions(...)` | `asha_voice_note_view.dart`, `patient_voice_symptom_view.dart` |
| `deprecated_member_use` — `activeColor` | Replaced `activeColor:` → `activeThumbColor:` on `Switch` | `admin_doctors_view.dart` |
| `deprecated_member_use` — `MaterialStateProperty` | Replaced → `WidgetStateProperty` | `admin_analytics_view.dart` |
| `prefer_const_constructors` | Changed `Row(children: const [...])` → `const Row(children: [...])` | `admin_analytics_view.dart`, `admin_asha_view.dart`, `admin_doctors_view.dart`, `patient_appointments_view.dart` |
| `unused_field` | Removed unused `_selectedFacilityFilter` field | `admin_analytics_view.dart` |

---

## 5. Lab Technician Data Entry & Patient Portal Sync Integration

### Background & Requirement
Previously, the Laboratory portal lacked an interface for the on-duty Lab Technician to add/create new diagnostic test orders directly or publish findings to a patient's health records. Additionally, Card 8 ("Lab Results") on the Patient Home screen showed static placeholder mock data.

### Enhancements Implemented
1. **Backend Endpoints (`FastAPI`)**:
   - `POST /api/v1/laboratory/orders`: Allows lab technicians to record diagnostic orders, findings, reference ranges, and auto-notify the ordering doctor.
   - `GET /api/v1/laboratory/patients/{patient_id}/results` & `GET /api/v1/patients/{patient_id}/lab-results`: Dynamic endpoints returning all verified diagnostic reports for a given patient.
2. **Lab Technician Portal UI (`laboratory_view.dart`)**:
   - Added **"Add Lab Test / Record Data"** button to the header banner.
   - Built the `_showCreateLabOrderDialog` modal featuring:
     - Target patient selector chips (`Ramesh Patil (HID10001)`, `Kavita Shinde (HID10003)`, `Suresh Gaikwad (HID10004)`, or Custom Patient Name/Health ID).
     - Quick chips for 8 standard diagnostic tests with pre-populated clinical finding templates (CBC, Fasting Blood Sugar, HbA1c, Rapid Malaria Antigen, Dengue NS1, Lipid Profile, LFT, Urine Routine).
     - Order/Result status selector (`Result Uploaded & Ready`, `Sample Collected`, `Pending Sample`).
     - Report Reference Number generator.
     - Direct publish button that saves data and sends notifications to the ordering clinician.
3. **Patient Portal Integration (`patient_home_view.dart`)**:
   - Upgraded Card 8 ("Lab Results") dialog `_showLabResultsDialog` to dynamically call `widget.api.fetchPatientLabResults(widget.session.id)`.
   - Displays real-time test orders, report reference numbers, ordering physician name, and numerical diagnostic findings with normal reference ranges.

### Visual Verification

- **Lab Data Entry Modal**:
  ![Lab Add Test Modal](file:///C:/Users/balas/.gemini/antigravity-ide/brain/07c7f5d3-51ec-48d9-8a86-e67c3c755938/lab_add_test_modal_1789639440630.png)

- **Lab Order Created in Lab Portal**:
  ![Lab Order Created](file:///C:/Users/balas/.gemini/antigravity-ide/brain/07c7f5d3-51ec-48d9-8a86-e67c3c755938/lab_order_created_in_portal_1789639552730.png)

- **Dynamic Lab Results on Patient Portal**:
  ![Patient Portal Lab Results](file:///C:/Users/balas/.gemini/antigravity-ide/brain/07c7f5d3-51ec-48d9-8a86-e67c3c755938/patient_lab_results_view_1789639778889.png)

---

## 6. Maharashtra State Public Health Starting Dashboard Redesign

### Design Implementation
The application starting / sign-in screen has been completely redesigned in [`unified_login_screen.dart`](file:///c:/Users/balas/Project/swasthyasetu_voice_module_UPDATED/swasthyasetu_voice_module%20-%20Copy/dashboard/lib/screens/unified_login_screen.dart) to match the official Government of Maharashtra Public Healthcare Grid aesthetic:

1. **Branding & Visual Palette**:
   - Deep emerald forest green background with radial shading (`#0D4B3E` to `#041C16`).
   - Large, high-resolution **Maharashtra Government Rajmudra (State Seal)** centered watermark.
   - Top golden circular emblem avatar with official seal and custom `S+` Healthcare Grid pill badge.
   - Bilingual Typography:
     - `SwasthyaSetu AI`
     - `महाराष्ट्र शासन - सार्वजनिक आरोग्य विभाग` (Government of Maharashtra - Public Health Department)
     - `Government of Maharashtra • Digital Public Healthcare Grid`
2. **Card 1: Healthcare Grid Sign In**:
   - Input field 1: `Phone number / मोबाईल क्रमांक` (styled with light slate background `#F8FAFC`, prefilled with default `9888888802`).
   - Input field 2: `Password / पासवर्ड` (obscured password `••••••••••`).
   - Saffron/Orange Action Button: **"Sign In to Healthcare Grid"** (`#F97316`), triggering full credential or 1-click role authentication.
3. **Card 2: Quick-Launch Demo Roles (Click to fill)**:
   - 2-Column interactive grid of demo roles with title, sub-tier facility tag, and active teal selection border (`#0D9488`):
     - `Frontline ASHA Worker (Priya...)` | `ASHA / Sub-Centre` (`9888888801`)
     - `PHC Medical Officer (Dr. Ram...)` | `Primary Care OPD` (`9888888802`)
     - `District Specialist (Dr. Anita D...)` | `Secondary / Hospital` (`9888888803`)
     - `District Admin (DHO Pune)` | `Command Center` (`9888888804`)
     - `Patient Rahul Jadhav (Active ...)` | `Referral & Care Journey` (`9888888805`)
     - `Patient Lakshmi Gaikwad (Dia...)` | `NCD & Teleconsult` (`9888888806`)
     - `Patient Sunita Shinde (Matern...)` | `High-Risk ANC Alert` (`9888888807`)
     - `PHC Lab Technician (Pooja...)` | `Diagnostic & Lab Portal` (`9888888808`)
   - Tapping any card updates the credential fields and highlights the active role.
4. **Backend Phone Number Mapping Support (`main.py`)**:
   - Added direct demo phone number authentication mapping for `9888888801` through `9888888808`.

### Visual Verification

- **Redesigned Maharashtra Public Health Starting Page**:
  ![Maharashtra Starting Page Full](file:///C:/Users/balas/.gemini/antigravity-ide/brain/07c7f5d3-51ec-48d9-8a86-e67c3c755938/maharashtra_starting_page_full_1789640346734.png)

- **Interactive Role Selection (Frontline ASHA Worker Highlighted)**:
  ![ASHA Role Highlighted](file:///C:/Users/balas/.gemini/antigravity-ide/brain/07c7f5d3-51ec-48d9-8a86-e67c3c755938/role_selection_asha_highlighted_1789641289464.png)

- **Successful Authentication into Portal**:
  ![ASHA Dashboard Overview](file:///C:/Users/balas/.gemini/antigravity-ide/brain/07c7f5d3-51ec-48d9-8a86-e67c3c755938/asha_dashboard_overview_1789641342587.png)

---

## 7. Header Navigation Bar Cleanup: Connectivity Badge Removed

- Removed the `GOOD INTERNET (WebRTC)` connectivity status pill/badge from the top header bar in [`unified_shell.dart`](file:///c:/Users/balas/Project/swasthyasetu_voice_module_UPDATED/swasthyasetu_voice_module%20-%20Copy/dashboard/lib/screens/unified_shell.dart).
- Cleaned up the app bar right-side actions to show solely:
  - Language Selector
  - Role Switcher
  - Emergency Red Flag Trigger
  - Session Logout

### Verification Screenshot
![Top Bar Connectivity Badge Removed](file:///C:/Users/balas/.gemini/antigravity-ide/brain/07c7f5d3-51ec-48d9-8a86-e67c3c755938/top_bar_connectivity_badge_removed_1789645447764.png)

---

## 8. Patient Portal: Location-Based Medicine Availability & Nearby Diagnostic Centres

### Overview
Equipped the Patient Portal with comprehensive location-based healthcare search capabilities, allowing patients to find real-time medicine availability across nearby pharmacies (PHC pharmacies, Jan Aushadhi Kendras, Government Hospitals, and private medical shops) as well as nearby diagnostic laboratories with transparent test pricing, turnaround times, and NABL accreditation status.

---

### Key Capabilities Implemented:

1. **Backend REST APIs ([`consent_interop_routes.py`](file:///c:/Users/balas/Project/swasthyasetu_voice_module_UPDATED/swasthyasetu_voice_module%20-%20Copy/backend/src/api/consent_interop_routes.py)):**
   - **`GET /api/v1/patient/nearby-pharmacies`**:
     - Accepts GPS coordinates (`lat`, `lng`), search radius (`radius_km`), and optional `medicine` query.
     - Returns nearby facilities with distance (km), contact number, open/closed status, operating hours, and medicine inventory with stock status (`available`, `low_stock`, `out_of_stock`) and pricing (Free NHM or retail).
   - **`GET /api/v1/patient/nearby-diagnostics`**:
     - Accepts GPS coordinates, search radius, and optional `test_type` query.
     - Returns diagnostic centres and labs with distance, NABL accreditation status, contact info, operating hours, and comprehensive test catalogs (CBC, Blood Glucose, Rapid Malaria, Thyroid, Lipid Profile, X-Ray, ECG, CT Scan) with turnaround times and pricing.

2. **Frontend UI & Interactive Dialogs ([`patient_nearby_services_dialogs.dart`](file:///c:/Users/balas/Project/swasthyasetu_voice_module_UPDATED/swasthyasetu_voice_module%20-%20Copy/dashboard/lib/widgets/patient_nearby_services_dialogs.dart)):**
   - **`NearbyMedicineAvailabilityDialog`**:
     - GPS status banner with patient location (`Shivaji Nagar, Anantapur`) and radius selector chips (`5 km`, `10 km`, `20 km`).
     - Real-time search bar + popular medicine quick filter chips (`All`, `Paracetamol`, `Metformin`, `Amoxicillin`, `Insulin`, `Cetirizine`, `ORS`).
     - Full pharmacy cards displaying live stock count, free NHM tags, "Call Pharmacy" and "Reserve Medicine" buttons.
   - **`NearbyDiagnosticCentresDialog`**:
     - Radius selector chips (`5 km`, `10 km`, `15 km`, `25 km`).
     - Diagnostic test search bar + common test filter chips (`All`, `CBC`, `Blood Glucose`, `Malaria`, `Thyroid`, `Lipid Profile`, `X-Ray`, `CT Scan`).
     - Lab cards highlighting NABL accreditation badges, test pricing, turnaround times, "Contact Lab" and "Book Test Slot" buttons.

3. **Patient Home View Integration ([`patient_home_view.dart`](file:///c:/Users/balas/Project/swasthyasetu_voice_module_UPDATED/swasthyasetu_voice_module%20-%20Copy/dashboard/lib/screens/patient/patient_home_view.dart)):**
   - **Location-Based Healthcare Banner**: Two prominent gradient cards placed directly above the services grid for instant discovery:
     - **Medicine Availability** (*Find stock in nearby pharmacies*)
     - **Nearby Diagnostic Centres** (*NABL Labs & PHC Pathology*)
   - Added **Nearby Medicines** and **Nearby Diagnostics** action cards to the Patient Services grid.

---

### Verification Screenshots

- **Nearby Medicine Availability Modal (with live stock, distance & NHM pricing)**:
  ![Nearby Medicine Availability Modal](file:///C:/Users/balas/.gemini/antigravity-ide/brain/07c7f5d3-51ec-48d9-8a86-e67c3c755938/medicine_availability_modal_1789649572638.png)

- **Nearby Diagnostic Centres & Labs Modal (with NABL badges, test pricing & turnaround times)**:
  ![Nearby Diagnostic Centres Modal](file:///C:/Users/balas/.gemini/antigravity-ide/brain/07c7f5d3-51ec-48d9-8a86-e67c3c755938/diagnostic_centres_modal_1789649658012.png)
