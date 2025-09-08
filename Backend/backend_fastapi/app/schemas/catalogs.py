from pydantic import BaseModel


class CatalogBase(BaseModel):
    id: int
    name: str
    active: bool

    class Config:
        from_attributes = True


class CatalogCreate(BaseModel):
    name: str
    active: bool = True


class IndustryRead(CatalogBase):
    pass


class VehicleTypeRead(CatalogBase):
    company_id: int | None = None
    company_name: str | None = None


class VehicleTypeCreate(CatalogCreate):
    pass


class EppItemRead(CatalogBase):
    pass


class MedicalExamRead(CatalogBase):
    pass


class CourseRead(CatalogBase):
    pass


class CostCenterRead(BaseModel):
    id: int
    code: str
    name: str
    active: bool

    class Config:
        from_attributes = True


class RequiredDocumentRead(BaseModel):
    id: int
    name: str
    entity: str
    active: bool

    class Config:
        from_attributes = True
