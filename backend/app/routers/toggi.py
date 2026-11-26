import requests
from fastapi import APIRouter, HTTPException, Query

from app.integration.toggifunworld import (
    ToggiAccessError,
    get_activities,
    get_packages,
    get_product_details,
)
from app.schemas.toggi import (
    ToggiActivityListResponse,
    ToggiPackageListResponse,
    ToggiProductDetailsResponse,
)

router = APIRouter(prefix="/toggi", tags=["Toggi Fun World"])


@router.get("/activities", response_model=ToggiActivityListResponse)
def toggi_activities(
    q: str | None = Query(default=None, min_length=1, max_length=80),
    refresh: bool = Query(default=False),
):
    try:
        return get_activities(query=q, refresh=refresh)
    except requests.RequestException as exc:
        raise HTTPException(status_code=502, detail="Could not reach Toggi Fun World's activity catalog.") from exc
    except ToggiAccessError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@router.get("/packages", response_model=ToggiPackageListResponse)
def toggi_packages(refresh: bool = Query(default=False)):
    try:
        return get_packages(refresh=refresh)
    except requests.RequestException as exc:
        raise HTTPException(status_code=502, detail="Could not reach Toggi Fun World's package page.") from exc
    except ToggiAccessError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@router.get("/product", response_model=ToggiProductDetailsResponse)
def toggi_product_details(
    product_url: str = Query(..., min_length=20, max_length=500),
    refresh: bool = Query(default=False),
):
    try:
        return get_product_details(product_url, refresh=refresh)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except requests.RequestException as exc:
        raise HTTPException(status_code=502, detail="Could not load this Toggi product page.") from exc
    except ToggiAccessError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
