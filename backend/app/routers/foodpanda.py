from fastapi import APIRouter, HTTPException

from app.integration.foodpanda import get_dhaka_catalog_info, validate_restaurant_url
from app.schemas.foodpanda import (
    FoodpandaCatalogInfo,
    FoodpandaRestaurantLinkRequest,
    FoodpandaRestaurantLinkResponse,
)

router = APIRouter(prefix="/foodpanda", tags=["Foodpanda"])


@router.get("/dhaka", response_model=FoodpandaCatalogInfo)
def foodpanda_dhaka_catalog():
    """Return the official Foodpanda Dhaka catalog link and integration note."""
    return get_dhaka_catalog_info()


@router.post("/validate-link", response_model=FoodpandaRestaurantLinkResponse)
def foodpanda_validate_link(payload: FoodpandaRestaurantLinkRequest):
    try:
        safe_url = validate_restaurant_url(payload.restaurant_url)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return {"source": "Foodpanda Bangladesh", "restaurant_url": safe_url, "valid": True}
