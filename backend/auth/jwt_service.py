from datetime import datetime, timedelta, timezone
from jose import jwt, JWTError
from config import get_settings

settings = get_settings()


def create_access_token(data: dict) -> str:
    """Create a JWT token with expiration."""
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.access_token_expire_minutes)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, settings.secret_key, algorithm=settings.algorithm)


def verify_token(token: str) -> dict | None:
    """Verify and decode a JWT token. Returns payload or None."""
    try:
        payload = jwt.decode(token, settings.secret_key, algorithms=[settings.algorithm])
        return payload
    except JWTError:
        return None


def get_user_id_from_token(token: str) -> int | None:
    """Extract user_id from a valid JWT token."""
    payload = verify_token(token)
    if payload is None:
        return None
    user_id = payload.get("user_id")
    return int(user_id) if user_id is not None else None
