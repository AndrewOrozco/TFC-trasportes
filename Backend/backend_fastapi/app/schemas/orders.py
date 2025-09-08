from pydantic import BaseModel
from typing import Optional


class OrderCardRead(BaseModel):
    id: int
    estado: str
    operator_id: Optional[int] = None
    vehicle_id: Optional[int] = None

    class Config:
        from_attributes = True


