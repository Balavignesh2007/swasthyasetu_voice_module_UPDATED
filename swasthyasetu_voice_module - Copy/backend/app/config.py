import os
from dataclasses import dataclass
from dotenv import load_dotenv

# Load .env file variables into environment
load_dotenv()
load_dotenv(os.path.join(os.path.dirname(__file__), '..', '.env'))

@dataclass
class Settings:
    DATABASE_URL: str = os.getenv('DATABASE_URL') or os.getenv('APP_DATABASE_URL') or 'sqlite:///./swasthyasetu.db'
    JWT_SECRET: str = os.getenv('JWT_SECRET', 'change-me-in-production')
    JWT_ALGORITHM: str = 'HS256'
    ACCESS_TOKEN_EXPIRE_MINUTES: int = int(os.getenv('ACCESS_TOKEN_EXPIRE_MINUTES', '480'))
    OPENAI_API_KEY: str = os.getenv('OPENAI_API_KEY', '')
    HUGGINGFACE_API_KEY: str = os.getenv('HF_TOKEN', '')
    # Twilio telephony
    TWILIO_ACCOUNT_SID: str = os.getenv('TWILIO_ACCOUNT_SID', '')
    TWILIO_AUTH_TOKEN: str = os.getenv('TWILIO_AUTH_TOKEN', '')
    TWILIO_PHONE_NUMBER: str = os.getenv('TWILIO_PHONE_NUMBER', '+17073470704')
    PUBLIC_BASE_URL: str = os.getenv('PUBLIC_BASE_URL', 'http://127.0.0.1:8000')
    PHONE_HASH_SALT: str = os.getenv('PHONE_HASH_SALT', 'dev-phone-salt')
    # Gemini AI (chatbot RAG)
    GEMINI_API_KEY: str = os.getenv('GEMINI_API_KEY', '')
    GEMINI_MODEL: str = os.getenv('GEMINI_MODEL', 'gemini-3.5-flash')

settings = Settings()
