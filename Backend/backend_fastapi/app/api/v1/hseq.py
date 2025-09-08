from datetime import date, timedelta
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List

from app.core import deps
from app.models.hseq import EmployeeDoc, Induction, PreOpInspection, HseqEvent
from app.models.ops import Operator
from app.schemas import hseq as s

router = APIRouter()


# Employee documents
@router.post("/docs", response_model=s.EmployeeDocRead)
def create_doc(payload: s.EmployeeDocCreate, db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    doc = EmployeeDoc(
        operator_id=payload.operator_id,
        tipo=payload.tipo,
        nombre=payload.nombre,
        vencimiento=date.fromisoformat(payload.vencimiento) if payload.vencimiento else None,
        url=payload.url,
        firmado=payload.firmado,
    )
    db.add(doc)
    db.commit()
    db.refresh(doc)
    return doc


@router.get("/docs", response_model=List[s.EmployeeDocRead])
def list_docs(db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    return db.query(EmployeeDoc).order_by(EmployeeDoc.id.desc()).all()


@router.get("/docs/vencimientos", response_model=List[s.EmployeeDocRead])
def upcoming_expirations(days: int = 30, db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    today = date.today()
    limit = today + timedelta(days=days)
    return (
        db.query(EmployeeDoc)
        .filter(EmployeeDoc.vencimiento != None)  # noqa: E711
        .filter(EmployeeDoc.vencimiento <= limit)
        .order_by(EmployeeDoc.vencimiento)
        .all()
    )


# Inductions
@router.post("/inductions", response_model=s.InductionRead)
def create_induction(payload: s.InductionCreate, db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    ind = Induction(operator_id=payload.operator_id, tema=payload.tema, fecha=date.fromisoformat(payload.fecha), aprobado=payload.aprobado)
    db.add(ind)
    db.commit()
    db.refresh(ind)
    return ind


@router.get("/inductions", response_model=List[s.InductionRead])
def list_inductions(db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    return db.query(Induction).order_by(Induction.fecha.desc()).all()


# Pre-operational inspections
@router.post("/preops", response_model=s.PreOpInspectionRead)
def create_preop(payload: s.PreOpInspectionCreate, db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    po = PreOpInspection(vehicle_id=payload.vehicle_id, fecha=date.fromisoformat(payload.fecha), resultado=payload.resultado, observaciones=payload.observaciones)
    db.add(po)
    db.commit()
    db.refresh(po)
    return po


@router.get("/preops", response_model=List[s.PreOpInspectionRead])
def list_preops(db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    return db.query(PreOpInspection).order_by(PreOpInspection.fecha.desc()).all()


# HSEQ events
@router.post("/events", response_model=s.HseqEventRead)
def create_event(payload: s.HseqEventCreate, db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    ev = HseqEvent(tipo=payload.tipo, fecha=date.fromisoformat(payload.fecha), order_id=payload.order_id, vehicle_id=payload.vehicle_id, operator_id=payload.operator_id, evidencias=payload.evidencias)
    db.add(ev)
    db.commit()
    db.refresh(ev)
    return ev


@router.get("/events", response_model=List[s.HseqEventRead])
def list_events(db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    return db.query(HseqEvent).order_by(HseqEvent.fecha.desc()).all()


# HR - backgrounds by name or license id (simple contains)
@router.get("/hr/backgrounds", response_model=List[s.OperatorBackgroundRead])
def operator_backgrounds(q: str, db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    like = f"%{q}%"
    return (
        db.query(Operator)
        .filter((Operator.nombre.ilike(like)) | (Operator.licencias.ilike(like)))
        .order_by(Operator.nombre)
        .all()
    )


# HR - document alerts by due date window
@router.get("/hr/alerts", response_model=List[s.DocAlertRead])
def doc_alerts(days: int = 30, db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    today = date.today()
    limit = today + timedelta(days=days)
    rows = (
        db.query(EmployeeDoc, Operator)
        .join(Operator, Operator.id == EmployeeDoc.operator_id)
        .filter(EmployeeDoc.vencimiento != None)  # noqa: E711
        .filter(EmployeeDoc.vencimiento <= limit)
        .all()
    )
    alerts: list[s.DocAlertRead] = []
    for doc, op in rows:
        days_remaining = (doc.vencimiento - today).days if doc.vencimiento else 0
        if days_remaining < 0:
            days_remaining = 0
        alerts.append(
            s.DocAlertRead(
                operator_id=op.id,
                operator_nombre=op.nombre,
                tipo=doc.tipo,
                nombre=doc.nombre,
                vencimiento=doc.vencimiento,  # type: ignore
                days_remaining=days_remaining,
            )
        )
    return alerts
