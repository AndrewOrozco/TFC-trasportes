from fastapi import APIRouter

from . import auth, health, catalogs, crm, quotes, ops, hseq, users, companies, whoami, orders, dashboard


api_router = APIRouter()
api_router.include_router(health.router, prefix="/health", tags=["health"])
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(catalogs.router, prefix="/catalogs", tags=["catalogs"])
api_router.include_router(crm.router, prefix="/crm", tags=["crm"])
api_router.include_router(quotes.router, prefix="/crm", tags=["crm"])
api_router.include_router(ops.router, prefix="/ops", tags=["ops"])
api_router.include_router(hseq.router, prefix="/hseq", tags=["hseq"])
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(companies.router, prefix="/companies", tags=["companies"])
api_router.include_router(whoami.router, prefix="/me", tags=["me"])
api_router.include_router(orders.router, prefix="/orders", tags=["orders"])
api_router.include_router(dashboard.router, prefix="/dashboard", tags=["dashboard"])



