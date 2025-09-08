from fastapi import FastAPI
from contextlib import asynccontextmanager
from pathlib import Path
import time
from app.core.config import settings
from app.db.base import Base
from app.db.session import engine, get_session_factory
from app.core.security import PasswordHelper
from app.models.user import User
from sqlalchemy.orm import Session
from sqlalchemy import inspect
from app.services.seed import seed_admin_user, seed_catalogs
from alembic.config import Config as AlembicConfig
from alembic import command as alembic_command

from app.api.v1 import api_router
import logging, sys


logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
logger = logging.getLogger("app")

@asynccontextmanager
async def lifespan(_: FastAPI):
    # Solo realizar seed en dev si las tablas ya existen (Alembic administra el esquema)
    if settings.APP_ENV != "production":
        logger.info("Lifespan start - env=dev")
        # Correr migraciones automáticamente en dev
        try:
            _run_alembic_upgrade_head()
            logger.info("Alembic upgrade head done")
        except Exception:
            logger.exception("Alembic upgrade failed")
        session_factory = get_session_factory()
        with session_factory() as db:  # type: ignore
            _seed_if_possible(db)
            logger.info("Seeding done (admin/catalogs)")
    yield
    logger.info("Lifespan shutdown")


def _seed_if_possible(db: Session) -> None:
    inspector = inspect(db.bind)
    # Seed usuario admin si existe tabla users
    if inspector.has_table("users"):
        seed_admin_user(db, settings)
    # Seed catálogos si existen tablas
    expected_tables = [
        "industries",
        "vehicle_types",
        "epp_items",
        "medical_exams",
        "courses",
        "cost_centers",
        "required_documents",
    ]
    if all(inspector.has_table(t) for t in expected_tables):
        seed_catalogs(db)


app = FastAPI(title=settings.APP_NAME, lifespan=lifespan)


@app.get("/health")
def healthcheck() -> dict:
    return {"status": "ok"}


app.include_router(api_router, prefix="/api/v1")


def _run_alembic_upgrade_head() -> None:
    backend_root = Path(__file__).resolve().parents[1]
    cfg_path = backend_root / "alembic.ini"
    logger.info(f"Using Alembic config at: {cfg_path}")
    cfg = AlembicConfig(str(cfg_path))
    alembic_command.upgrade(cfg, "head")


@app.middleware("http")
async def _reqlog(request, call_next):
    t0 = time.perf_counter()
    resp = await call_next(request)
    dt = (time.perf_counter() - t0) * 1000
    print(f"{request.method} {request.url.path} -> {resp.status_code} ({dt:.1f}ms)", flush=True)
    return resp