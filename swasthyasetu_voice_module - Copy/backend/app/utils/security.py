from datetime import datetime, timedelta, timezone
import hashlib, hmac, secrets
import jwt
from app.config import settings

# PBKDF2 avoids a hard runtime dependency on passlib/bcrypt while remaining a
# standard salted password KDF. Existing bcrypt hashes can be supported later
# by installing passlib[bcrypt] in production.
def hash_password(password: str) -> str:
    salt = secrets.token_bytes(16)
    digest = hashlib.pbkdf2_hmac('sha256', password.encode(), salt, 310_000)
    return 'pbkdf2_sha256$310000$' + salt.hex() + '$' + digest.hex()

def verify_password(password: str, encoded: str) -> bool:
    try:
        scheme, rounds, salt_hex, digest_hex = encoded.split('$', 3)
        if scheme != 'pbkdf2_sha256': return False
        digest = hashlib.pbkdf2_hmac('sha256', password.encode(), bytes.fromhex(salt_hex), int(rounds))
        return hmac.compare_digest(digest.hex(), digest_hex)
    except Exception:
        return False

def normalize_to_e164(phone: str) -> str:
    p = ''.join(ch for ch in phone if ch.isdigit() or ch == '+')
    if p.startswith('0'): p = '+91' + p[1:]
    elif p and not p.startswith('+'): p = '+91' + p
    return p

def hash_phone(phone: str) -> str:
    return hmac.new(settings.PHONE_HASH_SALT.encode(), normalize_to_e164(phone).encode(), hashlib.sha256).hexdigest()

def create_access_token(subject: str, role: str):
    exp = datetime.now(timezone.utc) + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    return jwt.encode({'sub': subject, 'role': role, 'exp': exp}, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)

def decode_access_token(token: str):
    return jwt.decode(token, settings.JWT_SECRET, algorithms=[settings.JWT_ALGORITHM])
