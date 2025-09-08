from sqlalchemy import String, Integer, ForeignKey, Date, DateTime, Text, Boolean
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.db.base import Base


class EmployeeDoc(Base):
    __tablename__ = "employee_docs"

    id: Mapped[int] = mapped_column(primary_key=True)
    operator_id: Mapped[int] = mapped_column(ForeignKey("operators.id", ondelete="CASCADE"), index=True)
    tipo: Mapped[str] = mapped_column(String(80))  # licencia, examen_medico, curso, epp
    nombre: Mapped[str] = mapped_column(String(160))
    vencimiento: Mapped[Date | None] = mapped_column(Date, nullable=True)
    url: Mapped[str | None] = mapped_column(String(300), nullable=True)
    firmado: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Induction(Base):
    __tablename__ = "inductions"

    id: Mapped[int] = mapped_column(primary_key=True)
    operator_id: Mapped[int] = mapped_column(ForeignKey("operators.id", ondelete="CASCADE"), index=True)
    tema: Mapped[str] = mapped_column(String(160))
    fecha: Mapped[Date] = mapped_column(Date)
    aprobado: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)


class PreOpInspection(Base):
    __tablename__ = "preop_inspections"

    id: Mapped[int] = mapped_column(primary_key=True)
    vehicle_id: Mapped[int] = mapped_column(ForeignKey("vehicles.id", ondelete="CASCADE"), index=True)
    fecha: Mapped[Date] = mapped_column(Date)
    resultado: Mapped[str] = mapped_column(String(40))  # ok|observaciones|no_apto
    observaciones: Mapped[str | None] = mapped_column(Text, nullable=True)


class HseqEvent(Base):
    __tablename__ = "hseq_events"

    id: Mapped[int] = mapped_column(primary_key=True)
    tipo: Mapped[str] = mapped_column(String(80))  # incidente|siniestro
    fecha: Mapped[Date] = mapped_column(Date)
    order_id: Mapped[int | None] = mapped_column(ForeignKey("service_orders.id", ondelete="SET NULL"), nullable=True)
    vehicle_id: Mapped[int | None] = mapped_column(ForeignKey("vehicles.id", ondelete="SET NULL"), nullable=True)
    operator_id: Mapped[int | None] = mapped_column(ForeignKey("operators.id", ondelete="SET NULL"), nullable=True)
    evidencias: Mapped[str | None] = mapped_column(Text, nullable=True)
