
import requests
import time

from bs4 import BeautifulSoup
from urllib.parse import urljoin


BASE_URL = "https://herfybd.com"

MENU_URL = f"{BASE_URL}/menu.ashx"

HEADERS = {
    "User-Agent": "Mozilla/5.0"
}


def fetch_page(url: str) -> BeautifulSoup:
    """Fetch a webpage and return its parsed HTML."""

    response = requests.get(
        url,
        headers=HEADERS,
        timeout=20
    )

    response.raise_for_status()

    return BeautifulSoup(response.text, "html.parser")

CACHE_DURATION = 30 * 60  # 30 minutes

_menu_cache = None
_cache_timestamp = 0


def get_herfy_menu() -> list[dict]:
    """Retrieve Herfy menu with caching and stale-cache fallback."""

    global _menu_cache, _cache_timestamp

    current_time = time.time()

    # Return cached data if it is still valid
    if (
        _menu_cache is not None
        and current_time - _cache_timestamp < CACHE_DURATION
    ):
        return _menu_cache

    try:
        # Fetch fresh data when cache is missing or expired
        soup = fetch_page(MENU_URL)

        menu = []

        for product in soup.select("a.btMenuItem[href*='/item/']"):
            name = product.select_one(".headline")
            category = product.select_one(".btSubTitle")
            price = product.select_one(".btMenuItemPrice")
            image = product.select_one(".btMenuItemImage img")

            product_data = {
                "name": name.get_text(strip=True) if name else None,
                "category": category.get_text(strip=True) if category else None,
                "price": price.get_text(strip=True) if price else None,
                "image_url": (
                    urljoin(BASE_URL, image.get("src"))
                    if image and image.get("src")
                    else None
                ),
                "product_url": (
                    urljoin(BASE_URL, product.get("href"))
                    if product.get("href")
                    else None
                )
            }

            menu.append(product_data)

        if not menu:
            raise ValueError("No menu items found on Herfy website")

        # Update cache only after successful scraping
        _menu_cache = menu
        _cache_timestamp = time.time()

        return menu

    except requests.RequestException:
        # Use old cached data if the website is unavailable
        if _menu_cache is not None:
            return _menu_cache

        # No cached data available, so propagate the error
        raise
