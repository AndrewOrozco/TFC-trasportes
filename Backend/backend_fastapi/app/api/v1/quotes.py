from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime, timezone

from app.core import deps
from app.models import orders as mo
from app.models.crm import Client, Lead
from app.schemas import quotes as s
from app.services.pricing import PricingService

router = APIRouter()


@router.post("/cotizaciones", response_model=s.QuotationRead)
def create_quotation(payload: s.QuotationCreate, db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    if not db.query(Client).get(payload.client_id):
        raise HTTPException(status_code=400, detail="Cliente inválido")
    if payload.lead_id and not db.query(Lead).get(payload.lead_id):
        raise HTTPException(status_code=400, detail="Lead inválido")

    q = mo.Quotation(client_id=payload.client_id, lead_id=payload.lead_id, tipo_servicio=payload.tipo_servicio, notas=payload.notas)
    db.add(q)
    db.flush()

    items = []
    subtotal = 0.0
    for it in payload.items:
        total = float(it.precio_unitario) * it.cantidad
        qi = mo.QuotationItem(quotation_id=q.id, descripcion=it.descripcion, cantidad=it.cantidad, precio_unitario=it.precio_unitario, total=total)
        db.add(qi)
        items.append(qi)
        subtotal += total

    q.subtotal = subtotal
    q.impuestos = subtotal * 0.19
    q.total = q.subtotal + q.impuestos

    db.commit()
    db.refresh(q)
    return q


@router.get("/cotizaciones", response_model=List[s.QuotationRead])
def list_quotations(db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    return db.query(mo.Quotation).order_by(mo.Quotation.id.desc()).all()


@router.patch("/cotizaciones/{qid}", response_model=s.QuotationRead)
def update_quotation(qid: int, payload: s.QuotationUpdate, db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    q = db.query(mo.Quotation).get(qid)
    if not q:
        raise HTTPException(status_code=404, detail="Cotización no encontrada")
    if payload.estado:
        q.estado = payload.estado
    if payload.notas is not None:
        q.notas = payload.notas
    if payload.items is not None:
        # reemplazo simple
        db.query(mo.QuotationItem).filter(mo.QuotationItem.quotation_id == q.id).delete()
        subtotal = 0.0
        for it in payload.items:
            total = float(it.precio_unitario) * it.cantidad
            db.add(mo.QuotationItem(quotation_id=q.id, descripcion=it.descripcion, cantidad=it.cantidad, precio_unitario=it.precio_unitario, total=total))
            subtotal += total
        q.subtotal = subtotal
        q.impuestos = subtotal * 0.19
        q.total = q.subtotal + q.impuestos
    db.commit()
    db.refresh(q)
    return q


@router.post("/pricing/calculate")
def calculate_price(payload: s.PricingRequest, db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    return PricingService.calculate_total(db, **payload.dict())


@router.post("/cotizaciones/{qid}/convertir", response_model=s.ServiceOrderRead)
def convert_to_order(qid: int, payload: s.ServiceOrderCreate, db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    q = db.query(mo.Quotation).get(qid)
    if not q or q.estado not in ("enviada", "aceptada", "borrador"):
        raise HTTPException(status_code=400, detail="Cotización inválida para conversión")
    order = mo.ServiceOrder(quotation_id=q.id, client_id=q.client_id, ruta_origen=payload.ruta_origen, ruta_destino=payload.ruta_destino)
    db.add(order)
    db.commit()
    db.refresh(order)
    return order


@router.post("/cotizaciones/{qid}/enviar", response_model=s.QuotationRead)
def send_quotation(qid: int, db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    q = db.query(mo.Quotation).get(qid)
    if not q:
        raise HTTPException(status_code=404, detail="Cotización no encontrada")
    q.estado = "enviada"
    q.sent_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(q)
    return q


@router.post("/cotizaciones/{qid}/aceptar", response_model=s.QuotationRead)
def accept_quotation(qid: int, db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    q = db.query(mo.Quotation).get(qid)
    if not q:
        raise HTTPException(status_code=404, detail="Cotización no encontrada")
    q.estado = "aceptada"
    q.accepted_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(q)
    return q
