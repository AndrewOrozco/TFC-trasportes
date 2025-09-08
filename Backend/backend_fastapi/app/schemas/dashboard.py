from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class DashboardCounts(BaseModel):
    programado: int = 0
    en_curso: int = 0
    completado: int = 0
    cancelado: int = 0


class DashboardRead(BaseModel):
    conductores: int
    vehiculos: int
    ordenes_activas: int
    estados: DashboardCounts
    last_updated: str


