
import requests

from fastapi import APIRouter, HTTPException

from app.integration.herfy import get_herfy_menu
from app.schemas.restaurant import RestaurantMenuResponse


router = APIRouter(
    prefix="/restaurants",
    tags=["Restaurants"]
)


@router.get(
    "/herfy/menu",
    response_model=RestaurantMenuResponse
)
def herfy_menu():
    try:
        menu = get_herfy_menu()

        return {
            "source": "Herfy Bangladesh",
            "count": len(menu),
            "menu": menu
        }

    except requests.RequestException:
        raise HTTPException(
            status_code=502,
            detail="Could not fetch menu from Herfy Bangladesh"
        )
