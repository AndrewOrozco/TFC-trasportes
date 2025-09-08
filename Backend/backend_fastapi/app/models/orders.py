from sqlalchemy import String, Integer, ForeignKey, Numeric, DateTime, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.db.base import Base


class Quotation(Base):
    __tablename__ = "quotations"

    id: Mapped[int] = mapped_column(primary_key=True)
    client_id: Mapped[int] = mapped_column(ForeignKey("clients.id"), index=True)
    lead_id: Mapped[int | None] = mapped_column(ForeignKey("leads.id"), nullable=True)
    tipo_servicio: Mapped[str] = mapped_column(String(20))  # liquida|seca|especial
    estado: Mapped[str] = mapped_column(String(20), default="borrador")  # borrador|enviada|aceptada|rechazada
    subtotal: Mapped[Numeric] = mapped_column(Numeric(18, 2), default=0)
    impuestos: Mapped[Numeric] = mapped_column(Numeric(18, 2), default=0)
    total: Mapped[Numeric] = mapped_column(Numeric(18, 2), default=0)
    notas: Mapped[str | None] = mapped_column(Text, nullable=True)
    sent_at: Mapped[DateTime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    accepted_at: Mapped[DateTime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    items: Mapped[list["QuotationItem"]] = relationship(back_populates="quotation", cascade="all,delete-orphan")


class QuotationItem(Base):
    __tablename__ = "quotation_items"

    id: Mapped[int] = mapped_column(primary_key=True)
    quotation_id: Mapped[int] = mapped_column(ForeignKey("quotations.id", ondelete="CASCADE"), index=True)
    descripcion: Mapped[str] = mapped_column(String(200))
    cantidad: Mapped[int] = mapped_column(Integer, default=1)
    precio_unitario: Mapped[Numeric] = mapped_column(Numeric(18, 2), default=0)
    total: Mapped[Numeric] = mapped_column(Numeric(18, 2), default=0)

    quotation: Mapped[Quotation] = relationship(back_populates="items")


class ServiceOrder(Base):
    __tablename__ = "service_orders"

    id: Mapped[int] = mapped_column(primary_key=True)
    quotation_id: Mapped[int] = mapped_column(ForeignKey("quotations.id"), index=True)
    client_id: Mapped[int] = mapped_column(ForeignKey("clients.id"), index=True)
    estado: Mapped[str] = mapped_column(String(20), default="programado")  # programado|en_curso|completado|cancelado
    ruta_origen: Mapped[str | None] = mapped_column(String(160), nullable=True)
    ruta_destino: Mapped[str | None] = mapped_column(String(160), nullable=True)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    company_id: Mapped[int | None] = mapped_column(ForeignKey("companies.id", ondelete="SET NULL"), nullable=True, index=True)
