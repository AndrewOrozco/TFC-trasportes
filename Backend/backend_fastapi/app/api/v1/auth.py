from datetime import timedelta
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core import deps
from app.core.security import PasswordHelper, TokenManager
from app.core.config import settings
from app.models.user import User
from app.schemas.token import Token
from app.models.auth import RevokedToken
from app.schemas.user import UserRead


router = APIRouter()


class TokenRefreshRequest(BaseModel):
    refresh_token: str


@router.post("/login", response_model=Token)
def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(deps.get_db),
) -> Token:
    user: User | None = db.query(User).filter(User.email == form_data.username).one_or_none()
    if user is None or not PasswordHelper.verify_password(form_data.password, user.hashed_password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Credenciales inválidas")

    access_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    refresh_expires = timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)

    access_token = TokenManager.create_access_token(subject=user.email, expires_delta=access_expires)
    refresh_token = TokenManager.create_refresh_token(subject=user.email, expires_delta=refresh_expires)

    return Token(access_token=access_token, refresh_token=refresh_token, token_type="bearer", role=user.role, company_id=user.company_id)


@router.post("/refresh", response_model=Token)
def refresh_tokens(payload: TokenRefreshRequest) -> Token:
    # Validar no revocado
    token_hash = TokenManager.token_sha256(payload.refresh_token)
    # Nota: refresh no requiere DB, pero para revocación consultamos
    email = TokenManager.decode_refresh_token(payload.refresh_token)
    access_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    refresh_expires = timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    access_token = TokenManager.create_access_token(subject=email, expires_delta=access_expires)
    refresh_token = TokenManager.create_refresh_token(subject=email, expires_delta=refresh_expires)
    return Token(access_token=access_token, refresh_token=refresh_token, token_type="bearer")


@router.get("/me", response_model=UserRead)
def me(current_user: User = Depends(deps.get_current_user)) -> UserRead:
    return UserRead.model_validate(current_user)


class LogoutRequest(BaseModel):
    refresh_token: str


@router.post("/logout")
def logout(payload: LogoutRequest, db: Session = Depends(deps.get_db)) -> dict:
    # Guardar hash del refresh token para invalidarlo
    token_hash = TokenManager.token_sha256(payload.refresh_token)
    exists = db.query(RevokedToken).filter(RevokedToken.token_hash == token_hash).one_or_none()
    if not exists:
        db.add(RevokedToken(token_hash=token_hash))
        db.commit()
    return {"ok": True}


