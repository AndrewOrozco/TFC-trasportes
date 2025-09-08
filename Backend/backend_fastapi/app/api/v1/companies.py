from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

from app.core import deps
from app.models.company import Company

router = APIRouter(dependencies=[Depends(deps.require_roles("super_admin"))])


@router.post("")
def create_company(name: str, nit: str | None = None, db: Session = Depends(deps.get_db)):
    if db.query(Company).filter(Company.name == name).one_or_none():
        raise HTTPException(status_code=409, detail="Nombre ya existe")
    comp = Company(name=name, nit=nit)
    db.add(comp)
    db.commit()
    db.refresh(comp)
    return {"id": comp.id, "name": comp.name, "nit": comp.nit}


@router.get("")
def list_companies(db: Session = Depends(deps.get_db)) -> List[dict]:
    rows = db.query(Company).order_by(Company.id.desc()).all()
    return [{"id": c.id, "name": c.name, "nit": c.nit} for c in rows]


@router.delete("/{company_id}")
def delete_company(company_id: int, db: Session = Depends(deps.get_db)):
    comp = db.query(Company).get(company_id)
    if not comp:
        raise HTTPException(status_code=404, detail="Empresa no encontrada")
    db.delete(comp)
    db.commit()
    return {"ok": True}





