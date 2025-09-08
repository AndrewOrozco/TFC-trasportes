from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core import deps
from app.models.user import User
from app.models.ops import Operator, Vehicle
from app.schemas.user import UserRead


router = APIRouter()


@router.get("", response_model=UserRead)
def whoami(current_user: User = Depends(deps.get_current_user), db: Session = Depends(deps.get_db)) -> UserRead:
    # Enriquecer con operador y vehículo principal si existe
    operator = db.query(Operator).filter(Operator.user_id == current_user.id).one_or_none()
    vehicle = None
    if operator and operator.primary_vehicle_id:
        vehicle = db.query(Vehicle).get(operator.primary_vehicle_id)

    return UserRead(
        id=current_user.id,
        email=current_user.email,
        role=current_user.role,
        company_id=current_user.company_id,
        operator_id=operator.id if operator else None,
        operator_name=operator.nombre if operator else None,
        operator_licenses=operator.licencias if operator else None,
        vehicle_id=vehicle.id if vehicle else None,
        vehicle_placa=vehicle.placa if vehicle else None,
    )


