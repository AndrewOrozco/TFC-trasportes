from pydantic import BaseModel


class UserRead(BaseModel):
    id: int
    email: str
    role: str
    company_id: int | None = None
    operator_id: int | None = None
    operator_name: str | None = None
    operator_licenses: str | None = None
    vehicle_id: int | None = None
    vehicle_placa: str | None = None

    class Config:
        from_attributes = True


class UserCreate(BaseModel):
    email: str
    password: str
    role: str = "user"
    company_id: int | None = None


class UserUpdate(BaseModel):
    role: str | None = None
    password: str | None = None
    company_id: int | None = None


