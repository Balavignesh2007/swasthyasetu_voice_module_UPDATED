"""Automated Tests for SwasthyaSetu Multilingual AI Chatbot & RAG Engine."""

from fastapi.testclient import TestClient
from app.main import app
from app.database.database import get_db, SessionLocal
from app.models.models import ChatMessage, EmergencyEvent
from src.chatbot.intent_detector import IntentDetector, ChatIntent
from src.chatbot.rag_engine import rag_engine
from src.chatbot.gemini_adapter import GeminiAdapter

client = TestClient(app)


class TestIntentDetector:
    def setup_method(self):
        self.detector = IntentDetector()

    def test_emergency_detection_english(self):
        intent, meta = self.detector.detect("I have severe chest pain and cannot breathe")
        assert intent == ChatIntent.EMERGENCY
        assert meta["is_emergency"] is True

    def test_emergency_detection_hindi(self):
        intent, meta = self.detector.detect("सीने में तेज दर्द है और सांस फूल रही है")
        assert intent == ChatIntent.EMERGENCY
        assert meta["is_emergency"] is True

    def test_symptom_report(self):
        intent, _ = self.detector.detect("I have had high fever, headache and body pain since 3 days")
        assert intent == ChatIntent.SYMPTOM_REPORT

    def test_health_faq(self):
        intent, _ = self.detector.detect("What is Janani Suraksha Yojana and how can pregnant women get it?")
        assert intent == ChatIntent.HEALTH_FAQ

    def test_appointment_request(self):
        intent, _ = self.detector.detect("Can I book a doctor appointment at the primary health centre?")
        assert intent == ChatIntent.APPOINTMENT_REQUEST

    def test_greeting(self):
        intent, _ = self.detector.detect("Hello SwasthyaSetu, good morning!")
        assert intent == ChatIntent.GREETING


class TestRAGEngine:
    def test_faq_loading(self):
        assert len(rag_engine.faq_items) > 0

    def test_search_maternal_health(self):
        results = rag_engine.search("maternal nutrition pregnancy IFA tablets", top_k=2)
        assert len(results) > 0
        categories = [r.get("category") for r in results]
        assert any("Maternal" in cat or "Care" in cat for cat in categories)

    def test_retrieve_context_string(self):
        context = rag_engine.retrieve_context("child diarrhea ORS", top_k=2)
        assert isinstance(context, str)
        assert "ORS" in context or "diarrhea" in context.lower()


class TestGeminiAdapter:
    def test_local_fallback_generation(self):
        adapter = GeminiAdapter()
        context = "Category: Child Health\nQuestion: How to treat diarrhea in children?\nAnswer: Give ORS solution after every loose stool with zinc tablets for 14 days."
        reply = adapter.generate_response("How to treat diarrhea in children at home?", context=context)
        assert isinstance(reply, str)
        assert len(reply) > 20
        assert "ORS" in reply or "rehydration" in reply.lower() or "swasthya" in reply.lower()


class TestChatbotEndpoints:
    def test_greeting_endpoint(self):
        res = client.post("/api/v1/chatbot/message", json={
            "message": "Hello, namaste!",
            "session_id": "test-session-greeting",
            "language": "en"
        })
        assert res.status_code == 200
        data = res.json()
        assert data["intent"] == "GREETING"
        assert "SwasthyaSetu" in data["reply"]
        assert data["is_emergency"] is False

    def test_emergency_alert_endpoint(self):
        res = client.post("/api/v1/chatbot/message", json={
            "message": "Help! Patient is unconscious and having chest pain!",
            "session_id": "test-session-emergency",
            "language": "en"
        })
        assert res.status_code == 200
        data = res.json()
        assert data["is_emergency"] is True
        assert data["intent"] == "EMERGENCY"
        assert "108" in data["reply"]

    def test_symptom_triage_endpoint(self):
        res = client.post("/api/v1/chatbot/message", json={
            "message": "I have mild cough and slight headache for two days",
            "session_id": "test-session-symptom",
            "language": "en"
        })
        assert res.status_code == 200
        data = res.json()
        assert data["intent"] == "SYMPTOM_REPORT"
        assert data["triage_level"] in ("ROUTINE", "URGENT", "EMERGENCY")
        assert len(data["extracted_symptoms"]) > 0

    def test_faq_endpoint(self):
        res = client.post("/api/v1/chatbot/message", json={
            "message": "How many ANC checkups should a pregnant mother have?",
            "session_id": "test-session-faq",
            "language": "en"
        })
        assert res.status_code == 200
        data = res.json()
        assert data["intent"] == "HEALTH_FAQ"
        assert len(data["rag_sources"]) > 0

    def test_chat_history(self):
        sid = "history-test-session-123"
        client.post("/api/v1/chatbot/message", json={
            "message": "Hi, what is ORS?",
            "session_id": sid,
            "language": "en"
        })
        res = client.get(f"/api/v1/chatbot/history/{sid}")
        assert res.status_code == 200
        history = res.json()
        assert len(history) >= 2  # user and assistant
        assert history[0]["role"] == "user"
        assert history[1]["role"] == "assistant"

    def test_faq_topics_endpoint(self):
        res = client.get("/api/v1/chatbot/faq-topics")
        assert res.status_code == 200
        data = res.json()
        assert data["total_faqs"] > 0
        assert len(data["categories"]) > 0
