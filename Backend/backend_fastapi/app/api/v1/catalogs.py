from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core import deps
from app.models import catalogs as m
from app.schemas import catalogs as s
from app.models.company import Company

router = APIRouter()


@router.get("/industries", response_model=list[s.IndustryRead])
def list_industries(db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    return db.query(m.Industry).order_by(m.Industry.name).all()


@router.get("/vehicle_types", response_model=list[s.VehicleTypeRead])
def list_vehicle_types(db: Session = Depends(deps.get_db), current=Depends(deps.get_current_user)):
    q = db.query(m.VehicleType)
    if current.role != "super_admin":
        # Ver solo globales (company_id null) y los de su empresa
        q = q.filter((m.VehicleType.company_id == None) | (m.VehicleType.company_id == current.company_id))  # noqa: E711
    rows = q.order_by(m.VehicleType.name).all()
    # Enriquecer con company_name
    company_map: dict[int, str] = {
        c.id: c.name for c in db.query(Company).all()
    }
    result: list[s.VehicleTypeRead] = []
    for vt in rows:
        result.append(s.VehicleTypeRead(
            id=vt.id,
            name=vt.name,
            active=vt.active,
            company_id=vt.company_id,
            company_name=company_map.get(vt.company_id) if vt.company_id else None,
        ))
    return result


@router.post("/vehicle_types", response_model=s.VehicleTypeRead, dependencies=[Depends(deps.require_roles("admin", "super_admin"))])
def create_vehicle_type(payload: s.VehicleTypeCreate, db: Session = Depends(deps.get_db), current=Depends(deps.get_current_user)):
    exists = db.query(m.VehicleType).filter(m.VehicleType.name == payload.name).one_or_none()
    if exists:
        raise HTTPException(status_code=409, detail="Tipo de vehículo ya existe")
    # super_admin crea global (company_id null); admin crea en su empresa
    company_id = None if current.role == "super_admin" else current.company_id
    vt = m.VehicleType(name=payload.name, active=payload.active, company_id=company_id)
    db.add(vt)
    db.commit()
    db.refresh(vt)
    return vt


@router.patch("/vehicle_types/{vt_id}", response_model=s.VehicleTypeRead, dependencies=[Depends(deps.require_roles("admin", "super_admin"))])
def update_vehicle_type(vt_id: int, payload: s.VehicleTypeCreate, db: Session = Depends(deps.get_db), current=Depends(deps.get_current_user)):
    vt = db.query(m.VehicleType).get(vt_id)
    if not vt:
        raise HTTPException(status_code=404, detail="Tipo de vehículo no encontrado")
    if current.role != "super_admin" and vt.company_id != current.company_id:
        raise HTTPException(status_code=403, detail="No permitido")
    # Validar nombre duplicado
    dup = db.query(m.VehicleType).filter(m.VehicleType.name == payload.name, m.VehicleType.id != vt_id).one_or_none()
    if dup:
        raise HTTPException(status_code=409, detail="Nombre ya existe")
    vt.name = payload.name
    vt.active = payload.active
    db.commit()
    db.refresh(vt)
    company_name = None
    if vt.company_id:
        c = db.query(Company).get(vt.company_id)
        company_name = c.name if c else None
    return s.VehicleTypeRead(id=vt.id, name=vt.name, active=vt.active, company_id=vt.company_id, company_name=company_name)


@router.delete("/vehicle_types/{vt_id}", dependencies=[Depends(deps.require_roles("admin", "super_admin"))])
def delete_vehicle_type(vt_id: int, db: Session = Depends(deps.get_db), current=Depends(deps.get_current_user)):
    vt = db.query(m.VehicleType).get(vt_id)
    if not vt:
        raise HTTPException(status_code=404, detail="Tipo de vehículo no encontrado")
    if current.role != "super_admin" and vt.company_id != current.company_id:
        raise HTTPException(status_code=403, detail="No permitido")
    db.delete(vt)
    db.commit()
    return {"ok": True}


@router.get("/epp_items", response_model=list[s.EppItemRead])
def list_epp_items(db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    return db.query(m.EppItem).order_by(m.EppItem.name).all()


@router.get("/medical_exams", response_model=list[s.MedicalExamRead])
def list_medical_exams(db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    return db.query(m.MedicalExam).order_by(m.MedicalExam.name).all()


@router.get("/courses", response_model=list[s.CourseRead])
def list_courses(db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    return db.query(m.Course).order_by(m.Course.name).all()


@router.get("/cost_centers", response_model=list[s.CostCenterRead])
def list_cost_centers(db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    return db.query(m.CostCenter).order_by(m.CostCenter.code).all()


@router.get("/required_documents", response_model=list[s.RequiredDocumentRead])
def list_required_documents(db: Session = Depends(deps.get_db), _: object = Depends(deps.get_current_user)):
    return db.query(m.RequiredDocument).order_by(m.RequiredDocument.name).all()
