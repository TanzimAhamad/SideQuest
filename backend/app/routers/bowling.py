import requests

from fastapi import APIRouter, HTTPException

from app.integration.toggi import get_toggi_bowling
from app.schemas.bowling import BowlingResponse


router = APIRouter(
    prefix="/bowling",
    tags=["Bowling"]
)


@router.get("/toggi", response_model=BowlingResponse)
def toggi_bowling():
    try:
        return get_toggi_bowling()

    except requests.RequestException:
        raise HTTPException(
            status_code=502,
            detail="Could not fetch bowling information from Toggi Fun World"
        )