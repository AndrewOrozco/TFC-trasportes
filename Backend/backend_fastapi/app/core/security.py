from datetime import datetime, timedelta, timezone
from typing import Any
import hashlib

from jose import JWTError, jwt
from passlib.context import CryptContext

from app.core.config import settings


class PasswordHelper:
    _context = CryptContext(schemes=["bcrypt"], deprecated="auto")

    @staticmethod
    def hash_password(plain_password: str) -> str:
        return PasswordHelper._context.hash(plain_password)

    @staticmethod
    def verify_password(plain_password: str, hashed_password: str) -> bool:
        return PasswordHelper._context.verify(plain_password, hashed_password)


class TokenManager:
    @staticmethod
    def _create_token(subject: str, expires_delta: timedelta, token_type: str) -> str:
        now = datetime.now(timezone.utc)
        payload: dict[str, Any] = {
            "sub": subject,
            "iat": int(now.timestamp()),
            "exp": int((now + expires_delta).timestamp()),
            "type": token_type,
        }
        return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)

    @staticmethod
    def create_access_token(subject: str, expires_delta: timedelta) -> str:
        return TokenManager._create_token(subject, expires_delta, token_type="access")

    @staticmethod
    def create_refresh_token(subject: str, expires_delta: timedelta) -> str:
        return TokenManager._create_token(subject, expires_delta, token_type="refresh")

    @staticmethod
    def decode_access_token(token: str) -> str:
        try:
            payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
            if payload.get("type") != "access":
                raise JWTError("Invalid token type")
            return str(payload["sub"])  # email
        except JWTError as exc:  # pragma: no cover - mapped to HTTP layer
            raise exc

    @staticmethod
    def decode_refresh_token(token: str) -> str:
        try:
            payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
            if payload.get("type") != "refresh":
                raise JWTError("Invalid token type")
            return str(payload["sub"])  # email
        except JWTError as exc:  # pragma: no cover
            raise exc

    @staticmethod
    def token_sha256(token: str) -> str:
        return hashlib.sha256(token.encode("utf-8")).hexdigest()




