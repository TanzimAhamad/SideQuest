
import requests
import time

from bs4 import BeautifulSoup
from urllib.parse import urljoin


BASE_URL = "https://www.toggifunworld.com"
BOWLING_URL = f"{BASE_URL}/product/bowling/"

HEADERS = {
    "User-Agent": "Mozilla/5.0"
}

CACHE_DURATION = 30 * 60  # 30 minutes

_bowling_cache = None
_cache_timestamp = 0


def fetch_page(url: str) -> BeautifulSoup:
    """Fetch a webpage and return its parsed HTML."""

    response = requests.get(
        url,
        headers=HEADERS,
        timeout=20
    )

    response.raise_for_status()

    return BeautifulSoup(response.text, "html.parser")



def get_toggi_bowling() -> dict:
    """Retrieve regular bowling information with caching."""

    global _bowling_cache, _cache_timestamp

    current_time = time.time()

    # Return cached data if it is still valid
    if (
        _bowling_cache is not None
        and current_time - _cache_timestamp < CACHE_DURATION
    ):
        return _bowling_cache

    try:
        soup = fetch_page(BOWLING_URL)

        name = soup.select_one("h1")
        price = soup.select_one("p.price")
        description = soup.select_one(
            ".woocommerce-product-details__short-description"
        )
        image = soup.select_one(
            ".woocommerce-product-gallery img"
        )
        stock = soup.select_one(".stock")

        bowling_data = {
            "name": name.get_text(strip=True) if name else None,
            "price": price.get_text(" ", strip=True) if price else None,
            "description": (
                description.get_text(" ", strip=True)
                if description else None
            ),
            "image_url": (
                urljoin(BASE_URL, image.get("src"))
                if image and image.get("src")
                else None
            ),
            "product_url": BOWLING_URL,
            "availability": (
                stock.get_text(" ", strip=True)
                if stock else None
            )
        }

        # Do not cache an invalid or empty response
        if not bowling_data["name"]:
            raise ValueError("Bowling information not found")

        # Update cache after successful scraping
        _bowling_cache = bowling_data
        _cache_timestamp = time.time()

        return bowling_data

    except requests.RequestException:
        # Return old cached data if website is unavailable
        if _bowling_cache is not None:
            return _bowling_cache

        raise
