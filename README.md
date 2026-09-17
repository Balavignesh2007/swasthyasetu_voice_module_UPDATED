🩺 SWASTHYASETHU

Low-Bandwidth Multimodal • AI-Assisted • Multilingual • Offline-First Healthcare

SwasthyaSethu is a unified digital healthcare platform designed to improve accessibility and quality of public healthcare services, particularly in rural and underserved communities.

🇮🇳 SMART INDIA HACKATHON 2026





Problem Statement ID

SIH26133

Problem Statement Title

Accessibility and quality of public healthcare services, particularly in rural and underserved areas

Theme

Health Tech / MedTech / BioTech

PS Category

Software

Team ID

127106

Team Name

Unique thing

1. 💡 UNIQUENESS OF OUR PRODUCT

🧠 Clinical Bridge

Clinical NLP converts patient descriptions into structured symptoms and connects them with suitable healthcare pathways.

Patient Language → Clinical NLP → Structured Symptoms → Care Pathway

🚨 Red-Flag Safety Layer & Early Escalation

SwasthyaSethu does not rely only on AI.

A dedicated rule-based danger-sign layer identifies potential emergency cases and supports escalation to frontline healthcare workers.

Symptoms → Danger-Sign Rules → Emergency Escalation

AI provides decision support; it does not replace clinical diagnosis.

🔄 Closed-Loop Referral

A referral should not become the end of the patient's journey.

SwasthyaSethu tracks the patient across:

Referral → Receiving Facility → Treatment → Follow-up

This supports continuity of care across healthcare facilities.

📶 Low-Bandwidth Multimodal Access

The platform is designed for areas where connectivity can be unreliable.

Voice interaction

SMS

Offline access

Adaptive audio/video

Phone-call fallback

Offline synchronization

2. 🚀 PROPOSED SOLUTION

SwasthyaSethu combines multiple healthcare services into one connected platform.

Core Modules

Module

Function

🗣️ Multilingual Telemedicine & E-Consultation

Voice-assisted doctor–patient consultation using speech-to-text, translation and TTS

📋 Digital Health Records

Secure consultations, prescriptions, reports, vitals and medical history

🧠 AI-Assisted Triage

NLP symptom extraction + danger-sign rules + urgency assessment

🔄 Referral Tracking

Tracks referrals across facilities

💊 Pharmacy Coordination

E-prescriptions, medicine stock and availability

🧪 Diagnostic Coordination

Test requests, queues, results and availability

🚨 Emergency Escalation

Emergency guidance, 112/108 access and frontline alerts

❤️ High-Risk Follow-up

Maternal, child and chronic-care follow-up

📊 Facility Management

Facility KPIs, referrals, staff and service gaps

🤖 Multilingual AI Assistant

Patient interaction, basic health guidance, schemes, records and escalation

3. 🔄 WORKFLOW

👤 Patient

🔒 Secure Login
      ↓
📅 Book Appointment
      ↓
🔍 Check Symptoms
      ↓
🗣️ Voice / Text Input
      ↓
🌐 Multilingual Processing
      ↓
🧠 AI-Assisted Triage
      ↓
🏥 Facility / Teleconsultation
      ↓
📋 Digital Health Record
      ↓
💊 E-Prescription
      ↓
🔄 Referral if Required
      ↓
🔔 Follow-up Alerts

👩‍⚕️ ASHA / ANM / CHO

➕ Register Patient
      ↓
❤️ Record Vitals
      ↓
🔍 Check Symptoms
      ↓
⚠️ Identify High-Risk Patients
      ↓
🔄 Track Referrals
      ↓
📅 Follow-up
      ↓
📶 Offline Support

👨‍⚕️ Doctor / Specialist

👤 View Patient
      ↓
🔍 View Symptoms
      ↓
📁 View Patient History
      ↓
🧪 Review Test Results
      ↓
💬 Consultation
      ↓
💊 E-Prescription
      ↓
➡️ Referral

💊 Pharmacist

📄 View E-Prescription
      ↓
💊 Dispense Medicine
      ↓
📦 Update Stock
      ↓
⚠️ Report Low / Out-of-Stock

🧪 Diagnostic / Laboratory Staff

📋 View Test Requests
      ↓
👤 Manage Test Queue
      ↓
🧪 Perform Test
      ↓
☁️ Upload Results
      ↓
✅ Update Availability

📊 Administration

📈 Monitor Quality KPIs
      ↓
🔄 Monitor Referrals
      ↓
🏥 Facility Performance
      ↓
👥 Manage Staff
      ↓
🔎 Identify Service Gaps

4. 🤖 AI-ASSISTED TRIAGE

SwasthyaSethu uses a layered AI/ML workflow.

Patient Voice / Text
        ↓
Speech-to-Text
     Whisper
        ↓
Language Translation
    IndicTrans2
        ↓
Clinical NLP
   MultiClinNER
        ↓
Symptom Extraction
        ↓
Red-Flag Rule Engine
        ↓
Feature Preparation
        ↓
XGBoost Triage Model
        ↓
 ┌────────┬────────┬────────────┐
 ↓        ↓        ↓
LOW      HIGH   EMERGENCY
 └────────┴────────┴────────────┘
             ↓
     Referral / Escalation

Triage Levels

Level

Meaning

🟢 LOW

Routine care / appropriate guidance

🟠 HIGH

Prompt clinical assessment

🔴 EMERGENCY

Immediate escalation / emergency pathway

Important: Triage is a healthcare decision-support capability and must not be presented as autonomous medical diagnosis.

5. 🏗️ TECHNICAL APPROACH

Technology Stack

Frontend

Flutter

Dart

PWA

Backend

Python

FastAPI

REST API

Database

PostgreSQL

PostGIS

SQLite

Offline Sync

AI / ML

XGBoost

Scikit-learn

MultiClinNER

Speech & Language

Whisper — Speech-to-Text

IndicTrans2 — Indian-language translation

TTS — Text-to-Speech

AI Assistant

Gemini API

Telemedicine & Communication

Jitsi

Twilio SMS & Voice

WhatsApp / Meta API

Notifications

Firebase FCM

Interoperability

FHIR R4

ABDM / ABHA

Authentication

JWT

RBAC

Security

AES-256

HTTPS / TLS

Audit Logging

Deployment

Docker

AWS

6. 🧩 SYSTEM ARCHITECTURE

                         USER DEVICES
              ┌────────────────────────────┐
              │ Android │ iOS │ Web / PWA  │
              └──────────────┬─────────────┘
                             ↓
                    ┌──────────────────┐
                    │ Flutter / Dart   │
                    │ Applications     │
                    └────────┬─────────┘
                             ↓
              ┌─────────────────────────────┐
              │ CLIENT-SIDE SERVICES        │
              │                             │
              │ SQLite • Local Storage      │
              │ Offline Sync • JWT Session  │
              └──────────────┬──────────────┘
                             ↓
                    ┌─────────────────┐
                    │ FastAPI Backend │
                    │ Python REST API │
                    └────────┬────────┘
                             │
           ┌─────────────────┼──────────────────┐
           ↓                 ↓                  ↓
    ┌──────────────┐  ┌─────────────┐  ┌─────────────┐
    │ AI/ML Layer  │  │ PostgreSQL  │  │   PostGIS   │
    │              │  │             │  │             │
    │ MultiClinNER │  │ Health Data │  │ Facilities  │
    │ XGBoost      │  │ Records     │  │ Pharmacies  │
    │ Scikit-learn │  │             │  │ Diagnostics │
    └──────────────┘  └─────────────┘  └─────────────┘
           │
           ↓
 ┌────────────────────────────────────────────────────┐
 │                 EXTERNAL SERVICES                   │
 │                                                    │
 │ Whisper • IndicTrans2 • Jitsi • Twilio             │
 │ WhatsApp • Firebase • ABDM / ABHA                 │
 └────────────────────────────────────────────────────┘

7. 👥 USER ROLES / PORTALS

Role

Portal

Main Capabilities

👤 Patient

Patient Portal

Appointments, symptoms, records, consultations

👩‍⚕️ ASHA/ANM/CHO

Worker Portal

Registration, vitals, risk follow-up, referrals

👨‍⚕️ Doctor

Doctor Portal

Patient history, tests, consultation, prescriptions

💊 Pharmacist

Pharmacy Portal

E-prescriptions and medicine stock

🧪 Laboratory

Laboratory Portal

Test requests, queues and reports

📊 Admin

Admin Portal

KPIs, referrals, facilities and staff

8. 📡 OFFLINE-FIRST ARCHITECTURE

Connectivity should not become a barrier to essential healthcare workflows.

                  ONLINE
                    ↓
              FastAPI Server
                    ↓
               PostgreSQL
                    ↑
              Sync Engine
                    ↑
               SQLite DB
                    ↑
                  OFFLINE
                    ↓
          Essential Healthcare
              Workflows
                    ↓
           Connection Restored
                    ↓
                Sync Data

Offline Capabilities

Local patient information

Essential health records

Offline emergency guidance

Offline-first workflows

Local data synchronization

SMS / voice fallback

Adaptive communication

9. 🌐 MULTILINGUAL HEALTHCARE

Patient speaks local language
            ↓
       Whisper STT
            ↓
     Language Processing
            ↓
       IndicTrans2
            ↓
      Clinical NLP
            ↓
     Healthcare Workflow
            ↓
      TTS / Response

Goal

Make healthcare interaction accessible to users who may prefer:

Marathi

Hindi

English

Other supported Indian languages

10. 🔐 SECURITY & PRIVACY

Healthcare data requires security by design.

User
 ↓
Authentication
 ↓
JWT
 ↓
RBAC
 ↓
Authorized API
 ↓
Encrypted Data
 ↓
Audit Logging

Security Controls

🔒 HTTPS / TLS

🔑 JWT authentication

👥 Role-Based Access Control

🛡️ AES-256 encryption

🧾 Audit logging

🔐 Secure credential management

🧩 Data minimization

🤝 Consent-based data exchange

11. 🧬 FHIR + ABDM / ABHA

SwasthyaSethu is designed with healthcare interoperability in mind.

Patient Health Record
        ↓
   SwasthyaSethu
        ↓
     FHIR R4
        ↓
  ABDM / ABHA
        ↓
Authorized Healthcare Facility

FHIR R4

Provides a standardized approach for representing healthcare information.

ABDM / ABHA

Supports authorized, consent-based health-record exchange within the appropriate ecosystem.

12. 📍 PHARMACY & DIAGNOSTIC COORDINATION

Pharmacy

E-Prescription
      ↓
Nearby Pharmacy
      ↓
Medicine Availability
      ↓
Dispense Medicine
      ↓
Update Stock

Diagnostics

Doctor Requests Test
      ↓
Nearby Diagnostic Facility
      ↓
Check Availability
      ↓
Test Queue
      ↓
Upload Result
      ↓
Doctor / Patient Record

PostGIS supports location-based discovery of nearby:

PHCs

CHCs

Hospitals

Pharmacies

Diagnostic centres

13. 🚨 EMERGENCY ESCALATION

SwasthyaSethu combines AI-assisted assessment with explicit safety rules.

Patient Symptoms
       ↓
Danger-Sign Detection
       ↓
Potential Emergency
       ↓
Emergency Guidance
       ↓
112 / 108 Access
       ↓
Frontline Worker Alert
       ↓
Appropriate Facility

This workflow is intended to support faster escalation and should be clinically validated before deployment.

14. ❤️ HIGH-RISK PATIENT FOLLOW-UP

Maternal Health

High-risk pregnancy identification

Monitoring

ANC follow-up

Referral tracking

Child Health

Follow-up alerts

Risk monitoring

Referral continuity

Chronic Care

Hypertension monitoring

Diabetes monitoring

Medication reminders

Follow-up alerts

Continuity Model

Risk Identification
       ↓
Risk Flag
       ↓
ASHA / ANM / CHO
       ↓
Doctor / Facility
       ↓
Treatment
       ↓
Follow-up
       ↓
Continuous Care

15. 📊 EXISTING PATIENT JOURNEY

Fragmented Journey

Patient Has Health Issue
        ↓
Asks Others / Searches
        ↓
Finds Facility
        ↓
Travels Long Distance
        ↓
Long Waiting Time
        ↓
Explains Symptoms
        ↓
Doctor Consultation
        ↓
Paper Prescription
        ↓
Referral if Required
        ↓
Medicines / Tests Elsewhere
        ↓
Returns Again
        ↓
Uncertain Follow-up

SwasthyaSethu Journey

Patient Has Health Issue
        ↓
Voice / Text in Local Language
        ↓
Multilingual Processing
        ↓
AI-Assisted Triage
        ↓
Nearby Facility / Appointment
        ↓
Teleconsultation / Doctor Visit
        ↓
E-Prescription
        ↓
Digital Health Record
        ↓
Medicine / Diagnostic Availability
        ↓
Digital Referral
        ↓
Follow-up & Alerts
        ↓
ASHA / ANM / CHO Support

16. 🏆 OUR DIFFERENTIATORS

Capability

SwasthyaSethu

AI-assisted triage

✅

Teleconsultation

✅

Appointment / queue management

✅

Closed-loop referral tracking

✅

Emergency escalation

✅

Offline / low-connectivity support

✅

Multilingual voice interaction

✅

FHIR R4 / ABDM-ready architecture

✅

Continuity across facility levels

✅

High-risk follow-up

✅

Facility / district dashboards

✅

No special hardware required

✅

Rural PHC-scale design

✅

17. 🧪 FEASIBILITY & VIABILITY

Technical Feasibility

The architecture uses established technologies:

Flutter

FastAPI

PostgreSQL / PostGIS

SQLite

XGBoost

Scikit-learn

Whisper

IndicTrans2

FHIR R4

ABDM / ABHA

Docker

Modular Feasibility

The platform can be implemented incrementally:

Telemedicine
     ↓
Digital Records
     ↓
AI-Assisted Triage
     ↓
Pharmacy
     ↓
Diagnostics
     ↓
Referral
     ↓
Follow-up
     ↓
Admin Analytics

Operational Feasibility

The platform connects existing healthcare roles:

Patients + ASHA/ANM/CHO + Doctors + Specialists + Pharmacies + Laboratories + Facilities + Administrators

Economic Feasibility

The proposed workflows can help reduce avoidable:

Travel

Waiting

Repeated visits

Referral delays

Unnecessary trips for unavailable medicines/tests

These are proposed benefits and require validation through pilot deployment.

Sustainability

Potential sustainability mechanisms include:

Government programs

CSR funding

Healthcare-institution partnerships

Phased implementation

Reuse of existing public-health infrastructure

18. 📈 SCALABILITY

Selected PHCs / CHCs
        ↓
Multiple Facilities
        ↓
Block / District Level
        ↓
Rural Healthcare Network

The modular architecture allows gradual expansion without requiring replacement of the existing public healthcare structure.

19. 🌱 IMPACT & BENEFITS

🏥 Access to Doctors

Teleconsultation can connect rural and underserved patients with doctors and specialists while reducing the need for some long-distance visits.

📶 Reliable Access

Offline-first records, SMS and voice workflows can help maintain essential access when internet connectivity is unreliable.

🛣️ Reduced Travel Burden

Digital triage, teleconsultation and facility discovery can help patients make better-informed travel decisions.

💊 Medicine & Diagnostic Availability

Availability information can help reduce unnecessary trips.

❤️ Healthcare Benefits

Digital records, triage, telemedicine and referral tracking support continuity of care.

💰 Economic Benefits

Reduced unnecessary travel, waiting time and repeated visits can reduce associated expenses and productivity losses.

🗣️ Social Benefits

Multilingual voice and telemedicine support can improve accessibility across literacy and language levels.

📚 Awareness & Preventive Care

AI-assisted symptom guidance and SMS/voice reminders can encourage timely care-seeking, regular check-ups and follow-up.

20. ⚠️ CHALLENGES & STRATEGIES

Challenge

Strategy

📱 Low digital literacy

Voice-first UI + local-language support

📶 Poor connectivity

Offline-first design + synchronization

🔒 Data privacy

Encryption + authentication + RBAC + audit logs

🚨 Emergency access

Emergency guidance + 112/108 + frontline alerts

👩‍⚕️ Worker adoption

Simple dashboards + short training

🏥 Government integration

Phased integration with selected PHCs/CHCs

21. 🧪 VALIDATION & RESPONSIBLE DEPLOYMENT

Healthcare AI must be validated before clinical deployment.

Proposed validation roadmap

Prototype
   ↓
Technical Testing
   ↓
NLP Evaluation
   ↓
ML Model Evaluation
   ↓
Safety / Red-Flag Testing
   ↓
Clinician Review
   ↓
Pilot Deployment
   ↓
Real-World Evaluation

Important

Prototype estimates are not clinical outcomes.

Clinical effectiveness and safety should be established through appropriate validation and pilot deployment.

26. 🗺️ IMPLEMENTATION ROADMAP

Phase 1 — Foundation

Authentication

RBAC

Patient registration

Facility database

Phase 2 — Healthcare Access

Appointments

Facility search

Teleconsultation

Phase 3 — AI

Voice input

Speech-to-text

Translation

Clinical NLP

Triage

Red-flag rules

Phase 4 — Digital Care

E-prescriptions

Digital records

Pharmacy

Diagnostics

Referrals

Phase 5 — Continuity

Follow-up alerts

ASHA/ANM/CHO workflows

High-risk tracking

Phase 6 — Intelligence

Facility KPIs

Service-gap analytics

District dashboards

Phase 7 — Validation

Technical testing

Model evaluation

Clinician review

Pilot deployment

Impact measurement

27. 🎬 RECOMMENDED DEMO FLOW

For the strongest demonstration, show one complete patient journey:

Patient Login
      ↓
Select Language
      ↓
Speak Symptoms
      ↓
Whisper Speech-to-Text
      ↓
IndicTrans2 Translation
      ↓
MultiClinNER Symptom Extraction
      ↓
Red-Flag Safety Check
      ↓
AI-Assisted Triage
      ↓
Nearby Facility
      ↓
Book / Teleconsult
      ↓
Doctor Reviews History
      ↓
E-Prescription
      ↓
Pharmacy / Diagnostics
      ↓
Digital Referral
      ↓
ASHA/ANM/CHO Follow-up Alert

⭐ Judge-facing demo principle

Show one patient from symptom → care → referral → follow-up.

This demonstrates that SwasthyaSethu is an end-to-end healthcare continuity platform, rather than only an AI model or telemedicine application.

28. 📚 RESEARCH & REFERENCES

The project research areas include:

Multilingual speech recognition

Machine-learning-based healthcare triage

Voice-based healthcare accessibility

Emergency alert systems

Rural and underserved healthcare

Offline-first healthcare applications

Maharashtra healthcare-system assessment

Healthcare transformation initiatives

The SIH proposal also compares SwasthyaSethu with existing solutions including:

eSanjeevani

Apollo 24|7

Tata 1mg

Practo

29. 🔗 PROJECT LINKS

Replace the placeholders:

🌐 Live Demo: <ADD_DEMO_URL>

💻 GitHub: <ADD_GITHUB_URL>

🎥 Demo Video: <ADD_DEMO_VIDEO_URL>

📄 Proof Documents: <ADD_PROOF_DOCUMENTS_URL>

30. ⚖️ MEDICAL & AI DISCLAIMER

SwasthyaSethu is a proposed healthcare technology and decision-support platform.

The AI components are intended to assist healthcare workflows and are not intended to replace qualified healthcare professionals or provide autonomous medical diagnosis.

Emergency and triage workflows should undergo appropriate clinical, safety, privacy and regulatory validation before real-world deployment.

🏆 WHY SWASTHYASETHU?

SwasthyaSethu does not solve only one problem.

It connects the complete healthcare journey:

        ACCESS
          ↓
     MULTILINGUAL
          ↓
      OFFLINE
          ↓
   AI-ASSISTED TRIAGE
          ↓
    SAFETY ESCALATION
          ↓
    TELECONSULTATION
          ↓
    DIGITAL RECORDS
          ↓
     PHARMACY + LAB
          ↓
      REFERRAL LOOP
          ↓
       FOLLOW-UP
          ↓
    CONTINUOUS CARE

Our core idea

Don't just connect patients to doctors — connect the entire healthcare journey.

❤️ SWASTHYASETHU

Bridging the gap between a patient's first symptom and continuous care.
