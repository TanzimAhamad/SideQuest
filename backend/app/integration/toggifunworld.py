"""Public product/package listing integration for Toggi Fun World.

Only public pages from the official Toggi Fun World website are requested.
The integration does not purchase tickets, reserve sessions, or bypass login
or access controls. Prices and operational availability can change; the app
always links back to the official product page for confirmation.
"""
from __future__ import annotations

import re
import time
from datetime import datetime, timezone
from typing import Any
from urllib.parse import urljoin, urlparse

import requests
from bs4 import BeautifulSoup, Tag

BASE_URL = "https://www.toggifunworld.com"
SHOP_URL = f"{BASE_URL}/shop/"
PACKAGES_URL = f"{BASE_URL}/toggi-packages/"
CONTACT_URL = f"{BASE_URL}/contacts/"
REQUEST_TIMEOUT = 20
MAX_SHOP_PAGES = 12
CACHE_SECONDS = 600
HEADERS = {
    "User-Agent": "Mozilla/5.0 (compatible; SideQuestAcademicProject/1.0)",
    "Accept": "text/html,application/xhtml+xml",
}
PRICE_RE = re.compile(r"(?:TK\.?|৳)\s*([\d,]+(?:\.\d{1,2})?)|([\d,]+(?:\.\d{1,2})?)\s*TK", re.IGNORECASE)
_product_cache: dict[str, Any] = {"at": 0.0, "data": None}
_package_cache: dict[str, Any] = {"at": 0.0, "data": None}
_detail_cache: dict[str, dict[str, Any]] = {}


class ToggiAccessError(RuntimeError):
    pass


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _fetch(url: str) -> BeautifulSoup:
    response = requests.get(url, headers=HEADERS, timeout=REQUEST_TIMEOUT)
    response.raise_for_status()
    if not response.text.strip():
        raise ToggiAccessError("Toggi Fun World returned an empty page.")
    return BeautifulSoup(response.text, "html.parser")


def _safe_product_url(value: str) -> str:
    parsed = urlparse(value)
    if parsed.scheme != "https" or parsed.netloc.lower() not in {"www.toggifunworld.com", "toggifunworld.com"}:
        raise ValueError("Select a product from the official Toggi Fun World website.")
    if not parsed.path.startswith("/product/"):
        raise ValueError("The link must point to a Toggi Fun World product page.")
    return f"{BASE_URL}{parsed.path}"


def _text(node: Tag | None) -> str | None:
    if node is None:
        return None
    value = re.sub(r"\s+", " ", node.get_text(" ", strip=True)).strip()
    return value or None


def _price(text: str | None) -> tuple[float | None, str | None]:
    if not text:
        return None, None
    match = PRICE_RE.search(text)
    if not match:
        return None, None
    raw_value = match.group(1) or match.group(2)
    value = float(raw_value.replace(",", ""))
    return value, match.group(0).strip()


def _product_card_nodes(soup: BeautifulSoup) -> list[Tag]:
    cards = soup.select("li.product, article.product, div.product.type-product, .products .product")
    if cards:
        return cards
    # Fallback for a WooCommerce theme with different card wrappers.
    found: list[Tag] = []
    seen: set[int] = set()
    for anchor in soup.select("a[href*='/product/']"):
        current: Tag | None = anchor
        for _ in range(7):
            if current is None or current.name in {"body", "html"}:
                break
            classes = " ".join(current.get("class", [])).casefold()
            if "product" in classes or current.name == "li":
                if id(current) not in seen:
                    found.append(current)
                    seen.add(id(current))
                break
            current = current.parent if isinstance(current.parent, Tag) else None
    return found


def _parse_product_card(card: Tag) -> dict[str, Any] | None:
    anchor = card.select_one("a.woocommerce-LoopProduct-link[href], a[href*='/product/']")
    if anchor is None or not anchor.get("href"):
        return None
    url = urljoin(BASE_URL, str(anchor.get("href")))
    try:
        url = _safe_product_url(url)
    except ValueError:
        return None

    title_node = card.select_one(".woocommerce-loop-product__title, h2, h3, h4")
    name = _text(title_node) or _text(anchor)
    if not name:
        image = card.find("img")
        name = str(image.get("alt", "")).strip() if image else None
    if not name:
        return None

    price_node = card.select_one(".price, .woocommerce-Price-amount, bdi")
    price_text = _text(price_node) or _text(card)
    price_bdt, price_label = _price(price_text)
    category_node = card.select_one(".product-category, .posted_in, .wc-product-categories")
    category = _text(category_node) or "Games & Rides"
    slug = urlparse(url).path.rstrip("/").split("/")[-1]
    product_id_match = re.search(r"(?:product/)([^/]+)", urlparse(url).path)
    return {
        "product_id": product_id_match.group(1) if product_id_match else slug,
        "name": name,
        "category": category,
        "price_bdt": price_bdt,
        "price_text": price_label,
        "product_url": url,
        "description": None,
        "product_type": "activity",
    }


def _next_page(soup: BeautifulSoup, current_url: str) -> str | None:
    selectors = [
        "a.next.page-numbers",
        "a.next",
        "a[rel='next']",
        ".woocommerce-pagination a.next",
    ]
    for selector in selectors:
        anchor = soup.select_one(selector)
        if anchor and anchor.get("href"):
            candidate = urljoin(current_url, str(anchor.get("href")))
            parsed = urlparse(candidate)
            if parsed.netloc.lower() in {"www.toggifunworld.com", "toggifunworld.com"}:
                return candidate
    return None


def get_activities(query: str | None = None, refresh: bool = False) -> dict[str, Any]:
    now = time.monotonic()
    cached = _product_cache.get("data")
    if not refresh and cached and now - float(_product_cache.get("at", 0)) < CACHE_SECONDS:
        result = dict(cached)
    else:
        current_url: str | None = SHOP_URL
        visited: set[str] = set()
        seen: set[str] = set()
        products: list[dict[str, Any]] = []
        pages_fetched = 0
        while current_url and current_url not in visited and pages_fetched < MAX_SHOP_PAGES:
            visited.add(current_url)
            soup = _fetch(current_url)
            pages_fetched += 1
            for card in _product_card_nodes(soup):
                item = _parse_product_card(card)
                if item and item["product_url"] not in seen:
                    seen.add(item["product_url"])
                    products.append(item)
            next_url = _next_page(soup, current_url)
            current_url = next_url if next_url and next_url not in visited else None
        result = {
            "source": "Toggi Fun World",
            "venue": "Toggi Fun World, Bashundhara City Shopping Mall, Panthapath, Dhaka",
            "catalog_url": SHOP_URL,
            "count": len(products),
            "pages_fetched": pages_fetched,
            "has_more": bool(current_url),
            "products": products,
            "fetched_at": _now_iso(),
            "price_notice": "Prices and availability may change. Confirm on the official Toggi page before visiting or purchasing.",
        }
        _product_cache["at"] = now
        _product_cache["data"] = result

    if query:
        needle = query.strip().casefold()
        filtered = [
            item for item in result["products"]
            if needle in item["name"].casefold() or needle in (item.get("category") or "").casefold()
        ]
        result = {**result, "count": len(filtered), "products": filtered}
    return result


def _package_card_nodes(soup: BeautifulSoup) -> list[Tag]:
    cards: list[Tag] = []
    seen: set[int] = set()
    excluded = {"regular packages", "packages", "toggi packages"}
    for heading in soup.find_all(["h2", "h3", "h4"]):
        heading_text = _text(heading)
        if not heading_text or heading_text.casefold() in excluded:
            continue
        for parent in heading.parents:
            if not isinstance(parent, Tag) or parent.name in {"body", "html"}:
                break
            text = _text(parent) or ""
            if len(text) > 1200:
                continue
            if PRICE_RE.search(text):
                if id(parent) not in seen:
                    cards.append(parent)
                    seen.add(id(parent))
                break
    return cards


def get_packages(refresh: bool = False) -> dict[str, Any]:
    now = time.monotonic()
    cached = _package_cache.get("data")
    if not refresh and cached and now - float(_package_cache.get("at", 0)) < CACHE_SECONDS:
        return cached

    soup = _fetch(PACKAGES_URL)
    packages_by_name: dict[str, dict[str, Any]] = {}
    for card in _package_card_nodes(soup):
        heading = card.find(["h2", "h3", "h4"])
        name = _text(heading)
        if not name:
            continue
        text = _text(card) or ""
        price_bdt, price_text = _price(text)
        if price_bdt is None:
            continue
        link = card.select_one("a[href*='/product/'], a[href]")
        url = urljoin(PACKAGES_URL, str(link.get("href"))) if link else PACKAGES_URL
        packages_by_name[name.casefold()] = {
            "package_id": re.sub(r"[^a-z0-9]+", "-", name.casefold()).strip("-"),
            "name": name,
            "price_bdt": price_bdt,
            "price_text": price_text,
            "description": text,
            "package_url": url,
            "product_type": "package",
        }
    packages = list(packages_by_name.values())

    result = {
        "source": "Toggi Fun World",
        "catalog_url": PACKAGES_URL,
        "count": len(packages),
        "packages": packages,
        "fetched_at": _now_iso(),
        "price_notice": "Package rates and conditions may change without notice. Confirm on the official page.",
    }
    _package_cache["at"] = now
    _package_cache["data"] = result
    return result


def get_product_details(product_url: str, refresh: bool = False) -> dict[str, Any]:
    safe_url = _safe_product_url(product_url)
    now = time.monotonic()
    cached = _detail_cache.get(safe_url)
    if not refresh and cached and now - cached["at"] < CACHE_SECONDS:
        return cached["data"]

    soup = _fetch(safe_url)
    title = soup.select_one("h1.product_title, h1.entry-title, h1")
    name = _text(title) or "Toggi Fun World activity"
    price_node = soup.select_one(".summary .price, p.price, .price")
    price_bdt, price_text = _price(_text(price_node))
    description_node = soup.select_one(".woocommerce-Tabs-panel--description, #tab-description, .woocommerce-product-details__short-description")
    category_node = soup.select_one(".posted_in, .product_meta .posted_in")
    data = {
        "source": "Toggi Fun World",
        "product_id": urlparse(safe_url).path.rstrip("/").split("/")[-1],
        "name": name,
        "category": _text(category_node) or "Games & Rides",
        "price_bdt": price_bdt,
        "price_text": price_text,
        "description": _text(description_node),
        "product_url": safe_url,
        "booking_url": safe_url,
        "fetched_at": _now_iso(),
        "price_notice": "Confirm the current price and operating status with Toggi Fun World.",
    }
    _detail_cache[safe_url] = {"at": now, "data": data}
    return data
