import asyncio
import json
import websockets
import requests
import time

WS_URL = "ws://127.0.0.1:8000/ws/alerts"
BASE_URL = "http://127.0.0.1:8000"

async def test_full_pipeline():
    print("=== Step 1: Connecting to WebSocket (/ws/alerts) ===")
    async with websockets.connect(WS_URL) as ws:
        print(" Connected to WebSocket successfully!")

        # Step 2: Simulate Twilio Incoming Call with a new CallSid
        call_sid = f"CA_FLOW_TEST_{int(time.time())}"
        from_number = "+919121458655"
        print(f"\n=== Step 2: Incoming Call (CallSid={call_sid}, From={from_number}) ===")
        resp = requests.post(f"{BASE_URL}/api/voice/incoming", data={
            "CallSid": call_sid,
            "From": from_number,
            "CallStatus": "ringing"
        })
        print(f"Status: {resp.status_code}")
        print("TwiML Response snippet:\n", resp.text[:200])

        # Step 3: Check that CallSession exists with this CallSid and patient identified
        resp_session = requests.get(f"{BASE_URL}/api/voice/calls/{call_sid}")
        print("Session in DB:", resp_session.json())
        assert resp_session.status_code == 200
        assert resp_session.json()["call_sid"] == call_sid
        print(" CallSession verified!")

        # Step 4: Patient Speaks Symptoms -> /api/voice/process-speech with SAME CallSid
        symptom_text = "Severe chest pain and shortness of breath with radiating left arm pain"
        print(f"\n=== Step 3: Patient Speaks (SpeechResult='{symptom_text}', same CallSid) ===")
        
        # Trigger process-speech in a background thread or synchronously
        def trigger_speech():
            time.sleep(0.5)
            r = requests.post(f"{BASE_URL}/api/voice/process-speech", data={
                "CallSid": call_sid,
                "From": from_number,
                "SpeechResult": symptom_text
            })
            print(f"Process-Speech Response status: {r.status_code}")

        import threading
        t = threading.Thread(target=trigger_speech)
        t.start()

        # Step 5: Wait for WebSocket broadcast
        print("\n=== Step 4: Waiting for real-time WebSocket broadcast on ASHA Dashboard stream ===")
        ws_msg = await asyncio.wait_for(ws.recv(), timeout=15.0)
        data = json.loads(ws_msg)
        print(" RECEIVED VIA WEBSOCKET:")
        print(json.dumps(data, indent=2))

        assert data.get("type") == "EMERGENCY_ALERT"
        alert = data.get("alert", {})
        print(" Alert ID:", alert.get("id"))
        print(" Call Session ID:", alert.get("call_session_id"))
        print(" Red Flag:", alert.get("red_flag_type"))
        print(" Patient Name:", alert.get("patient_name"))

        t.join()

        # Step 6: Verify updated CallSession
        resp_session_after = requests.get(f"{BASE_URL}/api/voice/calls/{call_sid}")
        session_data = resp_session_after.json()
        print("\n=== Step 5: Updated CallSession in DB ===")
        print(f"Status: {session_data.get('status')}")
        print(f"Triage Level: {session_data.get('triage_level')}")
        print(f"Risk Score: {session_data.get('risk_score')}")
        print(f"Transcript: {session_data.get('transcript')}")
        print(f"ASHA Alert JSON: {session_data.get('asha_alert')}")

        assert session_data.get("triage_level") in ["EMERGENCY", "URGENT"]
        assert session_data.get("status") == "COMPLETED"

        print("\n ALL WORKFLOW CRITERIA SUCCESSFULLY VERIFIED END-TO-END!")

if __name__ == "__main__":
    asyncio.run(test_full_pipeline())
