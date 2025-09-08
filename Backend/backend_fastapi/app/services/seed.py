from sqlalchemy.orm import Session

from app.core.security import PasswordHelper
from app.models.user import User
from app.models.catalogs import (
    Industry,
    VehicleType,
    EppItem,
    MedicalExam,
    Course,
    CostCenter,
    RequiredDocument,
)


def seed_admin_user(db: Session, settings) -> None:
    admin = db.query(User).filter(User.email == settings.ADMIN_EMAIL).one_or_none()
    if admin is None:
        password_hash = PasswordHelper.hash_password(settings.ADMIN_PASSWORD)
        admin = User(email=settings.ADMIN_EMAIL, hashed_password=password_hash, role="admin")
        db.add(admin)
        db.commit()


def seed_catalogs(db: Session) -> None:
    _seed_if_empty(db, Industry, [
        "Hidrocarburos", "Alimentos", "Químicos", "Construcción"
    ])
    _seed_if_empty(db, VehicleType, [
        "Sencillo", "Doble Troque", "Tractomula", "Cisterna"
    ])
    _seed_if_empty(db, EppItem, [
        "Casco", "Chaleco", "Guantes", "Botas"
    ])
    _seed_if_empty(db, MedicalExam, [
        "Ingreso", "Periódico", "Retiro"
    ])
    _seed_if_empty(db, Course, [
        "Alturas", "Manejo Defensivo", "Primeros Auxilios"
    ])
    _seed_cost_centers(db)
    _seed_if_empty(db, RequiredDocument, [
        ("SOAT", "vehiculo"),
        ("Tecnomecánica", "vehiculo"),
        ("Licencia Conducción", "operador"),
        ("Certificado ARL", "operador"),
    ], value_is_tuple=True)


def _seed_if_empty(db: Session, model, values, value_is_tuple: bool = False) -> None:
    if db.query(model).count() == 0:
        if value_is_tuple:
            for name, entity in values:
                db.add(model(name=name, entity=entity))
        else:
            for name in values:
                db.add(model(name=name))
        db.commit()


def _seed_cost_centers(db: Session) -> None:
    if db.query(CostCenter).count() == 0:
        db.add_all([
            CostCenter(code="CC-OPS", name="Operaciones"),
            CostCenter(code="CC-FLEET", name="Flota"),
            CostCenter(code="CC-HSEQ", name="HSEQ"),
        ])
        db.commit()







