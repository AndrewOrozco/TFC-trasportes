from sqlalchemy import String, Numeric, Boolean
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class PricingRule(Base):
    __tablename__ = "pricing_rules"

    id: Mapped[int] = mapped_column(primary_key=True)
    key: Mapped[str] = mapped_column(String(80), unique=True, nullable=False, index=True)
    coefficient: Mapped[Numeric] = mapped_column(Numeric(18, 6), nullable=False)
    unit: Mapped[str] = mapped_column(String(40), nullable=False)  # e.g., COP_per_km, percent, COP
    applies_to: Mapped[str] = mapped_column(String(20), nullable=False, default="all")  # liquida|seca|especial|all
    active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
