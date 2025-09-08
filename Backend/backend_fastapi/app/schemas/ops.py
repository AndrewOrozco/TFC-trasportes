from pydantic import BaseModel
from typing import Optional


class AllyCreate(BaseModel):
    name: str
    nit: Optional[str] = None
    contact: Optional[str] = None
    phone: Optional[str] = None


class AllyRead(AllyCreate):
    id: int
    active: bool = True

    class Config:
        from_attributes = True


class VehicleCreate(BaseModel):
    placa: str
    tipo_id: Optional[int] = None
    propio: bool = True
    ally_id: Optional[int] = None
    odometro: Optional[int] = None
    gps_id: Optional[str] = None
    company_id: Optional[int] = None


class VehicleRead(VehicleCreate):
    id: int
    active: bool = True
    tipo_nombre: Optional[str] = None

    class Config:
        from_attributes = True


class OperatorCreate(BaseModel):
    nombre: str
    rol: str = "conductor"
    licencias: Optional[str] = None
    restricciones_medicas: Optional[str] = None
    vetos: Optional[str] = None
    user_id: Optional[int] = None
    primary_vehicle_id: Optional[int] = None


class OperatorRead(OperatorCreate):
    id: int
    active: bool = True

    class Config:
        from_attributes = True


class AssignmentCreate(BaseModel):
    order_id: int
    vehicle_id: Optional[int] = None
    operator_id: Optional[int] = None
    ally_id: Optional[int] = None
    turno: Optional[str] = None
    horas_conduccion: Optional[int] = None


class AssignmentRead(AssignmentCreate):
    id: int

    class Config:
        from_attributes = True


class OrderEventCreate(BaseModel):
    order_id: int
    tipo: str
    message: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None


class OrderEventRead(OrderEventCreate):
    id: int

    class Config:
        from_attributes = True
