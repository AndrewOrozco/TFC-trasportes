from decimal import Decimal
from sqlalchemy.orm import Session

from app.models.pricing import PricingRule


class PricingService:
    @staticmethod
    def calculate_total(db: Session, tipo_servicio: str, distancia_km: float, peso_ton: float | None = None,
                        es_peligroso: bool | None = None, nocturno: bool | None = None, urgente: bool | None = None) -> dict:
        def coeff(key: str) -> Decimal:
            rule = (
                db.query(PricingRule)
                .filter(PricingRule.key == key, (PricingRule.applies_to == tipo_servicio) | (PricingRule.applies_to == "all"), PricingRule.active == True)  # noqa: E712
                .one_or_none()
            )
            return Decimal(rule.coefficient) if rule else Decimal(0)

        base_km = coeff("base_km")  # COP por km
        base = base_km * Decimal(distancia_km)

        # Modificadores
        peso_coef = coeff("peso_ton") * Decimal(peso_ton or 0)
        riesgo = coeff("riesgo_peligroso") if es_peligroso else Decimal(0)
        rec_noct = coeff("nocturno") if nocturno else Decimal(0)
        rec_urg = coeff("urgente") if urgente else Decimal(0)

        subtotal = base + peso_coef + riesgo + rec_noct + rec_urg
        impuestos = subtotal * coeff("iva_pct") / Decimal(100)
        total = subtotal + impuestos

        return {
            "subtotal": float(subtotal.quantize(Decimal("0.01"))),
            "impuestos": float(impuestos.quantize(Decimal("0.01"))),
            "total": float(total.quantize(Decimal("0.01"))),
        }
