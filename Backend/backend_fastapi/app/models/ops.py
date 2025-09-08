from sqlalchemy import String, Integer, ForeignKey, Boolean, Numeric, DateTime, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.db.base import Base


class Ally(Base):
    __tablename__ = "allies"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    nit: Mapped[str | None] = mapped_column(String(30), unique=True, nullable=True)
    contact: Mapped[str | None] = mapped_column(String(160), nullable=True)
    phone: Mapped[str | None] = mapped_column(String(60), nullable=True)
    active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)


class Vehicle(Base):
    __tablename__ = "vehicles"

    id: Mapped[int] = mapped_column(primary_key=True)
    placa: Mapped[str] = mapped_column(String(20), unique=True, index=True, nullable=False)
    tipo_id: Mapped[int | None] = mapped_column(ForeignKey("vehicle_types.id"), nullable=True)
    propio: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    ally_id: Mapped[int | None] = mapped_column(ForeignKey("allies.id"), nullable=True)
    odometro: Mapped[int | None] = mapped_column(Integer, nullable=True)
    gps_id: Mapped[str | None] = mapped_column(String(60), nullable=True)
    active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    company_id: Mapped[int | None] = mapped_column(ForeignKey("companies.id", ondelete="SET NULL"), nullable=True, index=True)


class Operator(Base):
    __tablename__ = "operators"

    id: Mapped[int] = mapped_column(primary_key=True)
    nombre: Mapped[str] = mapped_column(String(160), nullable=False)
    rol: Mapped[str] = mapped_column(String(60), default="conductor", nullable=False)
    licencias: Mapped[str | None] = mapped_column(Text, nullable=True)  # CSV simple p/ demo
    restricciones_medicas: Mapped[str | None] = mapped_column(Text, nullable=True)
    vetos: Mapped[str | None] = mapped_column(Text, nullable=True)
    active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    primary_vehicle_id: Mapped[int | None] = mapped_column(ForeignKey("vehicles.id", ondelete="SET NULL"), nullable=True, index=True)


class Assignment(Base):
    __tablename__ = "assignments"

    id: Mapped[int] = mapped_column(primary_key=True)
    order_id: Mapped[int] = mapped_column(ForeignKey("service_orders.id", ondelete="CASCADE"), index=True)
    vehicle_id: Mapped[int | None] = mapped_column(ForeignKey("vehicles.id"), nullable=True)
    operator_id: Mapped[int | None] = mapped_column(ForeignKey("operators.id"), nullable=True)
    ally_id: Mapped[int | None] = mapped_column(ForeignKey("allies.id"), nullable=True)
    turno: Mapped[str | None] = mapped_column(String(40), nullable=True)
    horas_conduccion: Mapped[int | None] = mapped_column(Integer, nullable=True)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class OrderEvent(Base):
    __tablename__ = "order_events"

    id: Mapped[int] = mapped_column(primary_key=True)
    order_id: Mapped[int] = mapped_column(ForeignKey("service_orders.id", ondelete="CASCADE"), index=True)
    tipo: Mapped[str] = mapped_column(String(40))  # programado|en_curso|soporte|completado|ubicacion
    message: Mapped[str | None] = mapped_column(Text, nullable=True)
    lat: Mapped[Numeric | None] = mapped_column(Numeric(10, 6), nullable=True)
    lng: Mapped[Numeric | None] = mapped_column(Numeric(10, 6), nullable=True)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())
