from fastapi import APIRouter


router = APIRouter()


@router.get("")
def health_v1() -> dict:
    return {"status": "ok", "version": "v1"}


