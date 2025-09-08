from pydantic import BaseModel
from typing import Optional, List


# Client
class ClientCreate(BaseModel):
    nit: str
    razon_social: str
    email: Optional[str] = None
    telefono: Optional[str] = None
    ubicaciones: Optional[list] = None


class ClientUpdate(BaseModel):
    razon_social: Optional[str] = None
    email: Optional[str] = None
    telefono: Optional[str] = None
    ubicaciones: Optional[list] = None


class ClientRead(BaseModel):
    id: int
    nit: str
    razon_social: str
    email: Optional[str]
    telefono: Optional[str]
    ubicaciones: Optional[list]
    company_id: Optional[int] = None
    created_by_user_id: Optional[int] = None
    updated_by_user_id: Optional[int] = None

    class Config:
        from_attributes = True


# Lead
class LeadCreate(BaseModel):
    client_id: Optional[int] = None
    fuente: Optional[str] = None
    industria_id: Optional[int] = None
    residuos: Optional[List[str]] = None
    cobertura: Optional[str] = None
    notas: Optional[str] = None
    score: Optional[int] = None


class LeadUpdate(BaseModel):
    fuente: Optional[str] = None
    industria_id: Optional[int] = None
    residuos: Optional[List[str]] = None
    cobertura: Optional[str] = None
    notas: Optional[str] = None
    score: Optional[int] = None
    estado: Optional[str] = None


class LeadRead(BaseModel):
    id: int
    client_id: Optional[int]
    fuente: Optional[str]
    industria_id: Optional[int]
    residuos: Optional[List[str]]
    cobertura: Optional[str]
    notas: Optional[str]
    score: Optional[int]
    estado: str

    class Config:
        from_attributes = True


# Opportunity
class OpportunityCreate(BaseModel):
    lead_id: int
    valor_estimado: Optional[float] = None
    probabilidad: Optional[float] = None
    etapa: Optional[str] = "prospecto"


class OpportunityUpdate(BaseModel):
    valor_estimado: Optional[float] = None
    probabilidad: Optional[float] = None
    etapa: Optional[str] = None


class OpportunityRead(BaseModel):
    id: int
    lead_id: int
    valor_estimado: Optional[float]
    probabilidad: Optional[float]
    etapa: str

    class Config:
        from_attributes = True


class ClientContactCreate(BaseModel):
    nombre: str
    cargo: Optional[str] = None
    email: Optional[str] = None
    telefono: Optional[str] = None


class ClientContactRead(BaseModel):
    id: int
    client_id: int
    nombre: str
    cargo: Optional[str]
    email: Optional[str]
    telefono: Optional[str]

    class Config:
        from_attributes = True
