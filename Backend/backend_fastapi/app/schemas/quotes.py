from pydantic import BaseModel
from typing import Optional, List


class QuotationItemIn(BaseModel):
    descripcion: str
    cantidad: int
    precio_unitario: float


class QuotationCreate(BaseModel):
    client_id: int
    lead_id: Optional[int] = None
    tipo_servicio: str
    notas: Optional[str] = None
    items: List[QuotationItemIn] = []


class QuotationUpdate(BaseModel):
    estado: Optional[str] = None
    notas: Optional[str] = None
    items: Optional[List[QuotationItemIn]] = None


class QuotationItemRead(BaseModel):
    id: int
    descripcion: str
    cantidad: int
    precio_unitario: float
    total: float

    class Config:
        from_attributes = True


class QuotationRead(BaseModel):
    id: int
    client_id: int
    lead_id: Optional[int]
    tipo_servicio: str
    estado: str
    subtotal: float
    impuestos: float
    total: float
    notas: Optional[str]
    items: List[QuotationItemRead] = []

    class Config:
        from_attributes = True


class PricingRequest(BaseModel):
    tipo_servicio: str
    distancia_km: float
    peso_ton: Optional[float] = None
    es_peligroso: Optional[bool] = None
    nocturno: Optional[bool] = None
    urgente: Optional[bool] = None


class ServiceOrderCreate(BaseModel):
    quotation_id: int
    ruta_origen: Optional[str] = None
    ruta_destino: Optional[str] = None


class ServiceOrderRead(BaseModel):
    id: int
    quotation_id: int
    client_id: int
    estado: str
    ruta_origen: Optional[str]
    ruta_destino: Optional[str]

    class Config:
        from_attributes = True
