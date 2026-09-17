from fastapi.testclient import TestClient
from app.main import app
from app.database.seed import seed_database

client = TestClient(app)

def test_full_specification_endpoints():
    # 1. Ensure seed data
    seed_database()

    # 2. Test 1-click Demo Login for all 6 roles
    roles = ['patient', 'health_worker', 'doctor', 'pharmacy', 'lab', 'phc_admin']
    tokens = {}
    for r in roles:
        res = client.post('/api/v1/auth/demo-login', json={'role': r})
        assert res.status_code == 200, f"Demo login failed for role: {r}"
        data = res.json()
        assert 'access_token' in data
        assert data['user']['role'] in (r, 'health_worker' if r == 'asha' else r)
        assert len(data['user']['permissions']) > 0
        tokens[r] = data['access_token']

    # 3. Test 2FA Flow
    # Login as doctor (requires 2FA)
    res_login = client.post('/api/v1/auth/login', json={'username': 'dr.sharma', 'password': 'doctor123'})
    assert res_login.status_code == 200
    login_data = res_login.json()
    assert login_data.get('requires_2fa') is True
    assert 'challenge_id' in login_data

    # Verify 2FA
    res_2fa = client.post('/api/v1/auth/verify-2fa', json={
        'user_id': login_data['user_id'],
        'code': '123456',
        'challenge_id': login_data['challenge_id']
    })
    assert res_2fa.status_code == 200
    verify_data = res_2fa.json()
    assert verify_data.get('verified_2fa') is True
    assert 'access_token' in verify_data

    # 4. Test PHC Administration & Live Quality Dashboard
    res_fac = client.get('/api/v1/phc-admin/facility-status?facility_id=fac-phc-001')
    assert res_fac.status_code == 200
    fac_data = res_fac.json()
    assert fac_data['facility']['name'] == 'Shivaji Nagar PHC'
    assert fac_data['doctor_available'] is True

    res_qual = client.get('/api/v1/phc-admin/quality?facility_id=fac-phc-001')
    assert res_qual.status_code == 200
    qual_data = res_qual.json()
    kpis = qual_data['kpis']
    assert 'avg_waiting_time_minutes' in kpis
    assert 'referrals' in kpis
    assert 'followups' in kpis
    assert 'no_show_rate_percent' in kpis
    assert 'medicine_stockout' in kpis
    assert 'diagnostic_services' in kpis
    assert 'service_volume_trends' in qual_data

    # 5. Test Pharmacy (Dispense & Inventory deduction)
    res_rx = client.get('/api/v1/pharmacy/orders?facility_id=fac-phc-001')
    assert res_rx.status_code == 200
    rx_orders = res_rx.json()['orders']
    assert len(rx_orders) >= 1
    
    pending_rx = next((o for o in rx_orders if o['status'] == 'pending'), None)
    if pending_rx:
        disp_res = client.post(f"/api/v1/pharmacy/orders/{pending_rx['id']}/dispense", json={'dispensed_by': 'pharma_demo'})
        assert disp_res.status_code == 200
        assert disp_res.json()['status'] in ('success', 'already_dispensed')

    res_inv = client.get('/api/v1/pharmacy/inventory?facility_id=fac-phc-001')
    assert res_inv.status_code == 200
    assert len(res_inv.json()['inventory']) >= 3

    # 6. Test Laboratory (Sample collection & Result upload)
    res_lab = client.get('/api/v1/laboratory/orders?facility_id=fac-phc-001')
    assert res_lab.status_code == 200
    lab_orders = res_lab.json()['orders']
    assert len(lab_orders) >= 1

    pending_lab = next((o for o in lab_orders if o['status'] == 'pending'), None)
    if pending_lab:
        col_res = client.post(f"/api/v1/laboratory/orders/{pending_lab['id']}/sample-collected", json={'technician_name': 'Pooja Shinde'})
        assert col_res.status_code == 200
        up_res = client.post(f"/api/v1/laboratory/orders/{pending_lab['id']}/upload-result", json={
            'result_ref': 'LAB-TEST-0099',
            'result_summary': 'Malaria antigen negative; blood smear normal.'
        })
        assert up_res.status_code == 200

    # 7. Test Consent, ABDM Interoperability, FHIR R4
    res_con = client.post('/api/v1/consent/check', json={
        'patient_id': 'pat-001',
        'requested_by': 'usr-doctor-001',
        'required_scope': 'tier_2_records'
    })
    assert res_con.status_code == 200
    assert res_con.json()['authorized'] is True

    res_abdm = client.post('/api/v1/interop/abdm/verify-abha', json={'health_id': 'HID10001'})
    assert res_abdm.status_code == 200
    assert res_abdm.json()['status'] == 'VERIFIED'

    res_fhir = client.get('/api/v1/interop/fhir/patient/pat-001')
    assert res_fhir.status_code == 200
    assert res_fhir.json()['standard'] == 'HL7 FHIR Release 4'

    # 8. Test Offline Sync with Idempotency Key
    res_sync = client.post('/api/v1/sync', json={
        'client_id': 'mobile-offline-client-01',
        'items': [
            {
                'idempotency_key': 'offline-case-unique-key-001',
                'operation': 'create_case',
                'payload': {
                    'patient_id': 'pat-001',
                    'symptom_text': 'Seasonal allergic cough with nasal congestion',
                    'severity': 'routine'
                }
            }
        ]
    })
    assert res_sync.status_code == 200
    assert res_sync.json()['processed_count'] == 1

    # Repeat with same key -> should be skipped (idempotent)
    res_sync2 = client.post('/api/v1/sync', json={
        'client_id': 'mobile-offline-client-01',
        'items': [
            {
                'idempotency_key': 'offline-case-unique-key-001',
                'operation': 'create_case',
                'payload': {'patient_id': 'pat-001'}
            }
        ]
    })
    assert res_sync2.status_code == 200
    assert res_sync2.json()['skipped_count'] == 1

    # 9. Test AI Safety Principle Disclaimer in Voice Triage
    res_triage = client.post('/api/v1/voice/process-text', json={'text': 'Mild fever and dry cough for two days'})
    if res_triage.status_code == 200:
        tdata = res_triage.json()
        assert 'AI-assisted suggestion only — does not diagnose' in str(tdata)

    print("All Full Specification Backend Tests Passed Successfully!")

if __name__ == "__main__":
    test_full_specification_endpoints()
