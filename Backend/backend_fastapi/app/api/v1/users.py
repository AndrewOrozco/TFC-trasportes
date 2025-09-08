from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

from app.core import deps
from app.core.security import PasswordHelper
from app.models.user import User
from app.schemas.user import UserRead, UserCreate, UserUpdate

router = APIRouter()


@router.post("", response_model=UserRead)
def create_user(payload: UserCreate, db: Session = Depends(deps.get_db), current=Depends(deps.get_current_user)):
    # admin solo en su empresa; super_admin puede en cualquiera
    if current.role != "super_admin":
        payload.company_id = current.company_id
        if payload.role == "super_admin":
            raise HTTPException(status_code=403, detail="No permitido crear super_admin")
    if db.query(User).filter(User.email == payload.email).one_or_none():
        raise HTTPException(status_code=409, detail="Email ya registrado")
    hashed = PasswordHelper.hash_password(payload.password)
    assigned_company_id = payload.company_id if current.role == "super_admin" else current.company_id
    user = User(email=payload.email, hashed_password=hashed, role=payload.role, company_id=assigned_company_id)
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.get("", response_model=List[UserRead])
def list_users(db: Session = Depends(deps.get_db), current=Depends(deps.get_current_user)):
    q = db.query(User)
    if current.role != "super_admin":
        q = q.filter(User.company_id == current.company_id)
    return q.order_by(User.id.desc()).all()


@router.patch("/{user_id}", response_model=UserRead)
def update_user(user_id: int, payload: UserUpdate, db: Session = Depends(deps.get_db), current=Depends(deps.get_current_user)):
    user = db.query(User).get(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    if current.role != "super_admin":
        if user.company_id != current.company_id:
            raise HTTPException(status_code=403, detail="No permitido")
        if payload.role == "super_admin":
            raise HTTPException(status_code=403, detail="No permitido cambiar a super_admin")
        # Forzar que no cambie a otra empresa
        if payload.company_id is not None and payload.company_id != current.company_id:
            raise HTTPException(status_code=403, detail="No permitido cambiar de empresa")
    if payload.role is not None:
        user.role = payload.role
    if payload.password:
        user.hashed_password = PasswordHelper.hash_password(payload.password)
    if payload.company_id is not None:
        user.company_id = payload.company_id
    db.commit()
    db.refresh(user)
    return user


@router.delete("/{user_id}")
def delete_user(user_id: int, db: Session = Depends(deps.get_db), current=Depends(deps.get_current_user)):
    user = db.query(User).get(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    if current.role != "super_admin" and user.company_id != current.company_id:
        raise HTTPException(status_code=403, detail="No permitido")
    db.delete(user)
    db.commit()
    return {"ok": True}


