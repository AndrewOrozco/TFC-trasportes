from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

from app.core import deps
from app.models import ops as mo
from app.models.orders import ServiceOrder
from app.models.user import User
from app.models.catalogs import VehicleType
from app.schemas import ops as s

router = APIRouter()


# Allies
@router.post("/allies", response_model=s.AllyRead)
def create_ally(payload: s.AllyCreate, db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    ally = mo.Ally(**payload.dict())
    db.add(ally)
    db.commit()
    db.refresh(ally)
    return ally


@router.get("/allies", response_model=List[s.AllyRead])
def list_allies(db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    return db.query(mo.Ally).order_by(mo.Ally.name).all()


# Vehicles
@router.post("/vehicles", response_model=s.VehicleRead)
def create_vehicle(payload: s.VehicleCreate, db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    if db.query(mo.Vehicle).filter(mo.Vehicle.placa == payload.placa).one_or_none():
        raise HTTPException(status_code=409, detail="Placa ya registrada")
    vehicle = mo.Vehicle(**payload.dict())
    db.add(vehicle)
    db.commit()
    db.refresh(vehicle)
    return vehicle


@router.get("/vehicles", response_model=List[s.VehicleRead])
def list_vehicles(page: int = 1, per_page: int = 20, db: Session = Depends(deps.get_db), current=Depends(deps.get_current_user)):
    q = db.query(mo.Vehicle)
    if current.role != "super_admin":
        q = q.filter(mo.Vehicle.company_id == current.company_id)
    items = q.order_by(mo.Vehicle.placa).offset((page-1)*per_page).limit(per_page).all()
    # enrich tipo_nombre
    types = {t.id: t.name for t in db.query(VehicleType).all()}
    result: list[s.VehicleRead] = []
    for v in items:
        result.append(s.VehicleRead(
            id=v.id,
            placa=v.placa,
            tipo_id=v.tipo_id,
            propio=v.propio,
            ally_id=v.ally_id,
            odometro=v.odometro,
            gps_id=v.gps_id,
            active=v.active,
            tipo_nombre=types.get(v.tipo_id),
        ))
    return result


# Operators
@router.post("/operators", response_model=s.OperatorRead)
def create_operator(payload: s.OperatorCreate, db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    op = mo.Operator(**payload.dict())
    db.add(op)
    db.commit()
    db.refresh(op)
    return op


@router.get("/operators", response_model=List[s.OperatorRead])
def list_operators(role: str | None = None, page: int = 1, per_page: int = 20, db: Session = Depends(deps.get_db), current=Depends(deps.get_current_user)):
    # join a users para scoping por company
    q = db.query(mo.Operator).join(User, mo.Operator.user_id == User.id, isouter=True)
    if role:
        q = q.filter(mo.Operator.rol == role)
    # scope: por company via usuario relacionado (si lo tiene)
    if current.role != "super_admin":
        q = q.filter((User.company_id == current.company_id) | (mo.Operator.user_id == None))  # noqa: E711
    items = q.order_by(mo.Operator.id.desc()).offset((page-1)*per_page).limit(per_page).all()
    return items


# Assignment
@router.post("/orders/{order_id}/assignments", response_model=s.AssignmentRead)
def assign_order(order_id: int, payload: s.AssignmentCreate, db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    order = db.query(ServiceOrder).get(order_id)
    if not order:
        raise HTTPException(status_code=404, detail="Orden no encontrada")
    # si la orden no tiene company_id, intentar inferirla del vehículo u operador asignado
    if order.company_id is None:
        try:
            veh = db.query(mo.Vehicle).get(payload.vehicle_id) if payload.vehicle_id else None
            if veh and veh.company_id is not None:
                order.company_id = veh.company_id
        except Exception:
            pass
    asg = mo.Assignment(order_id=order_id, vehicle_id=payload.vehicle_id, operator_id=payload.operator_id, ally_id=payload.ally_id, turno=payload.turno, horas_conduccion=payload.horas_conduccion)
    db.add(asg)
    db.commit()
    db.refresh(asg)
    return asg


# Tracking
@router.post("/orders/{order_id}/events", response_model=s.OrderEventRead)
def add_event(order_id: int, payload: s.OrderEventCreate, db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    if not db.query(ServiceOrder).get(order_id):
        raise HTTPException(status_code=404, detail="Orden no encontrada")
    ev = mo.OrderEvent(order_id=order_id, tipo=payload.tipo, message=payload.message, lat=payload.lat, lng=payload.lng)
    db.add(ev)
    db.commit()
    db.refresh(ev)
    return ev


@router.get("/orders/{order_id}/events", response_model=List[s.OrderEventRead])
def list_events(order_id: int, db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    return db.query(mo.OrderEvent).filter(mo.OrderEvent.order_id == order_id).order_by(mo.OrderEvent.id).all()


# Order status update
@router.patch("/orders/{order_id}/estado")
def update_order_status(order_id: int, estado: str, db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    order = db.query(ServiceOrder).get(order_id)
    if not order:
        raise HTTPException(status_code=404, detail="Orden no encontrada")
    order.estado = estado
    db.commit()
    return {"ok": True, "order_id": order_id, "estado": estado}


# Last GPS position from events
@router.get("/orders/{order_id}/last_position")
def get_last_position(order_id: int, db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    ev = (
        db.query(mo.OrderEvent)
        .filter(mo.OrderEvent.order_id == order_id, mo.OrderEvent.tipo == "ubicacion")
        .order_by(mo.OrderEvent.id.desc())
        .first()
    )
    if not ev or ev.lat is None or ev.lng is None:
        raise HTTPException(status_code=404, detail="Sin ubicación registrada")
    return {"lat": float(ev.lat), "lng": float(ev.lng), "message": ev.message}
