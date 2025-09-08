from datetime import datetime, timezone
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core import deps
from app.models.ops import Operator, Vehicle
from app.models.orders import ServiceOrder
from app.models.user import User
from app.schemas.dashboard import DashboardRead, DashboardCounts

router = APIRouter()


@router.get("", response_model=DashboardRead)
@router.get("/", response_model=DashboardRead)
def get_dashboard(company_id: int | None = None, db: Session = Depends(deps.get_db), current=Depends(deps.get_current_user)):
    # Determinar company a consultar
    target_company_id = None
    if current.role == "super_admin" and company_id is not None:
        target_company_id = company_id
    elif current.role != "super_admin":
        target_company_id = current.company_id

    # Conductores por company usando join a users
    q_ops = db.query(Operator).join(User, Operator.user_id == User.id, isouter=True).filter(Operator.rol == "conductor")
    if target_company_id is not None:
        q_ops = q_ops.filter(User.company_id == target_company_id)
    conductores = q_ops.count()

    # Vehículos por company (excluir NULL a menos que sea super_admin sin company)
    q_veh = db.query(Vehicle)
    if target_company_id is not None:
        q_veh = q_veh.filter(Vehicle.company_id == target_company_id)
    vehiculos = q_veh.count()

    # Órdenes activas por company
    q_ord = db.query(ServiceOrder)
    if target_company_id is not None:
        q_ord = q_ord.filter(ServiceOrder.company_id == target_company_id)
    activos = q_ord.filter(ServiceOrder.estado.in_(["programado", "en_curso"])) .count()

    # Conteos por estado (mismo scope)
    q_all = db.query(ServiceOrder)
    if target_company_id is not None:
        q_all = q_all.filter(ServiceOrder.company_id == target_company_id)
    estados = DashboardCounts(
        programado=q_all.filter(ServiceOrder.estado == "programado").count(),
        en_curso=q_all.filter(ServiceOrder.estado == "en_curso").count(),
        completado=q_all.filter(ServiceOrder.estado == "completado").count(),
        cancelado=q_all.filter(ServiceOrder.estado == "cancelado").count(),
    )
    return DashboardRead(
        conductores=conductores,
        vehiculos=vehiculos,
        ordenes_activas=activos,
        estados=estados,
        last_updated=datetime.now(timezone.utc).isoformat(),
    )


