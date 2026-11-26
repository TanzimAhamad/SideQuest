"""Authorized-link integration for Foodpanda Bangladesh.

Foodpanda's public developer portal is a partner API, not a general consumer
catalog API. This module deliberately does not scrape, copy, or republish its
restaurant names, menu text, prices, images, or other protected content.
It returns official links and validates a restaurant URL selected by the user.
"""
from urllib.parse import urlparse

FOODPANDA_BASE_URL = "https://www.foodpanda.com.bd"
DHAKA_CATALOG_URL = f"{FOODPANDA_BASE_URL}/city/dhaka"


def get_dhaka_catalog_info() -> dict:
    return {
        "source": "Foodpanda Bangladesh",
        "city": "Dhaka",
        "catalog_url": DHAKA_CATALOG_URL,
        "access_mode": "official_link",
        "note": (
            "Open Foodpanda to browse restaurants and menus for the delivery area. "
            "Return to SideQuest and enter the selected restaurant, optional dish, "
            "price, and official restaurant URL for group nomination."
        ),
    }


def validate_restaurant_url(restaurant_url: str) -> str:
    parsed = urlparse(restaurant_url.strip())
    allowed_hosts = {"www.foodpanda.com.bd", "foodpanda.com.bd"}
    if parsed.scheme != "https" or parsed.netloc.lower() not in allowed_hosts:
        raise ValueError("Use an HTTPS restaurant link from foodpanda.com.bd.")
    if "/restaurant/" not in parsed.path.lower():
        raise ValueError("The link must point to a Foodpanda restaurant page.")
    return f"{FOODPANDA_BASE_URL}{parsed.path}"
