from pydantic import BaseModel
from typing import Optional
from datetime import date


class EmployeeDocCreate(BaseModel):
    operator_id: int
    tipo: str
    nombre: str
    vencimiento: Optional[str] = None  # YYYY-MM-DD
    url: Optional[str] = None
    firmado: bool = False


class EmployeeDocRead(EmployeeDocCreate):
    id: int
    vencimiento: Optional[date] = None

    class Config:
        from_attributes = True


class InductionCreate(BaseModel):
    operator_id: int
    tema: str
    fecha: str
    aprobado: bool = True


class InductionRead(InductionCreate):
    id: int
    fecha: date

    class Config:
        from_attributes = True


class PreOpInspectionCreate(BaseModel):
    vehicle_id: int
    fecha: str
    resultado: str
    observaciones: Optional[str] = None


class PreOpInspectionRead(PreOpInspectionCreate):
    id: int
    fecha: date

    class Config:
        from_attributes = True


class HseqEventCreate(BaseModel):
    tipo: str
    fecha: str
    order_id: Optional[int] = None
    vehicle_id: Optional[int] = None
    operator_id: Optional[int] = None
    evidencias: Optional[str] = None


class HseqEventRead(HseqEventCreate):
    id: int
    fecha: date

    class Config:
        from_attributes = True


# HR responses
class OperatorBackgroundRead(BaseModel):
    id: int
    nombre: str
    rol: str
    licencias: Optional[str] = None
    restricciones_medicas: Optional[str] = None
    vetos: Optional[str] = None

    class Config:
        from_attributes = True


class DocAlertRead(BaseModel):
    operator_id: int
    operator_nombre: str
    tipo: str
    nombre: str
    vencimiento: date
    days_remaining: int
