from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List

from app.core import deps
from app.models.orders import ServiceOrder
from app.models.ops import Assignment
from app.schemas.orders import OrderCardRead

router = APIRouter()


@router.get("", response_model=List[OrderCardRead])
def list_orders(status: str | None = None, page: int = 1, per_page: int = 20, db: Session = Depends(deps.get_db), current=Depends(deps.get_current_user)):
    q = db.query(ServiceOrder)
    if status in ("programado", "en_curso", "completado", "cancelado"):
        q = q.filter(ServiceOrder.estado == status)
    if current.role != "super_admin":
        q = q.filter(ServiceOrder.company_id == current.company_id)
    orders = q.order_by(ServiceOrder.id.desc()).offset((page-1)*per_page).limit(per_page).all()
    # mapa asignaciones (simple: última asignación por order)
    asg_map = {}
    if orders:
        ids = [o.id for o in orders]
        asg_rows = (
            db.query(Assignment)
            .filter(Assignment.order_id.in_(ids))
            .all()
        )
        for a in asg_rows:
            asg_map[a.order_id] = a
    return [
        OrderCardRead(
            id=o.id,
            estado=o.estado,
            operator_id=asg_map.get(o.id).operator_id if asg_map.get(o.id) else None,
            vehicle_id=asg_map.get(o.id).vehicle_id if asg_map.get(o.id) else None,
        )
        for o in orders
    ]


@router.get("/me", response_model=List[OrderCardRead])
def my_orders(status: str | None = None, page: int = 1, per_page: int = 20, db: Session = Depends(deps.get_db), current=Depends(deps.get_current_user)):
    # encontrar operator_id del usuario si existe
    from app.models.ops import Operator
    op = db.query(Operator).filter(Operator.user_id == current.id).one_or_none()
    if not op:
        return []
    q = db.query(ServiceOrder).join(Assignment, Assignment.order_id == ServiceOrder.id).filter(Assignment.operator_id == op.id)
    if status in ("programado", "en_curso", "completado", "cancelado"):
        q = q.filter(ServiceOrder.estado == status)
    orders = q.order_by(ServiceOrder.id.desc()).offset((page-1)*per_page).limit(per_page).all()
    # devolver con operator/vehicle de la asignación
    asg_map = {}
    if orders:
        ids = [o.id for o in orders]
        asg_rows = (
            db.query(Assignment)
            .filter(Assignment.order_id.in_(ids))
            .all()
        )
        for a in asg_rows:
            asg_map[a.order_id] = a
    return [
        OrderCardRead(
            id=o.id,
            estado=o.estado,
            operator_id=asg_map.get(o.id).operator_id if asg_map.get(o.id) else None,
            vehicle_id=asg_map.get(o.id).vehicle_id if asg_map.get(o.id) else None,
        )
        for o in orders
    ]


