"""Public listing parser for Blockbuster Cinemas.

The integration reads publicly visible movie and schedule pages only. It does
not log in, reserve seats, or submit ticket purchases. Always verify prices and
availability on the official booking page before confirming an outing.
"""
from __future__ import annotations

import re
from urllib.parse import urljoin, urlparse

import requests
from bs4 import BeautifulSoup, Tag

BASE_URL = "https://www.blockbusterbd.com"
NOW_SHOWING_URL = f"{BASE_URL}/now-showing"
SCHEDULE_URL = f"{BASE_URL}/schedule"
HEADERS = {
    "User-Agent": "Mozilla/5.0 (compatible; SideQuestAcademicProject/1.0)",
    "Accept": "text/html,application/xhtml+xml",
}
TIME_RE = re.compile(r"\b(\d{1,2}:\d{2}\s*(?:AM|PM))\b", re.IGNORECASE)
MOVIE_ID_RE = re.compile(r"/movie-details/([^/?#]+)", re.IGNORECASE)
OLD_MOVIE_ID_RE = re.compile(r"/Movies/Details/([^/?#]+)", re.IGNORECASE)


def fetch_page(url: str) -> BeautifulSoup:
    response = requests.get(url, headers=HEADERS, timeout=20)
    response.raise_for_status()
    return BeautifulSoup(response.text, "html.parser")


def _absolute(url: str | None, base: str = BASE_URL) -> str | None:
    if not url:
        return None
    return urljoin(base, url.strip())


def _image_from(container: Tag | None) -> str | None:
    if container is None:
        return None
    image = container.select_one("img[src], img[data-src], img[data-lazy-src]")
    if image:
        for key in ("src", "data-src", "data-lazy-src"):
            value = image.get(key)
            if value and not str(value).startswith("data:"):
                return _absolute(str(value))
    for node in [container, *container.select("[style]")]:
        style = node.get("style", "")
        match = re.search(r"url\(['\"]?(.*?)['\"]?\)", str(style))
        if match:
            return _absolute(match.group(1))
    return None


def _movie_id(url: str | None, fallback: str) -> str:
    if url:
        match = MOVIE_ID_RE.search(url) or OLD_MOVIE_ID_RE.search(url)
        if match:
            return match.group(1)
    return re.sub(r"[^a-z0-9]+", "-", fallback.casefold()).strip("-") or "unknown"


def _closest_card(anchor: Tag) -> Tag:
    for parent in anchor.parents:
        if not isinstance(parent, Tag) or parent.name in {"body", "html"}:
            break
        text = parent.get_text(" ", strip=True)
        if len(text) > 1800:
            continue
        if parent.find(["h1", "h2", "h3", "h4", "h5", "h6"]):
            return parent
        classes = " ".join(parent.get("class", []))
        if any(token in classes.casefold() for token in ("movie", "card", "film", "item")) and len(text) > 8:
            return parent
    return anchor.parent if isinstance(anchor.parent, Tag) else anchor


def _label_value(text: str, label: str) -> str | None:
    labels = r"CAST|GENRE|DIRECTOR|RUNTIME|RELEASE DATE|FORMAT|RATING|PRICE|MORE"
    match = re.search(rf"\b{re.escape(label)}\s*:?\s*(.*?)(?=\b(?:{labels})\s*:?|$)", text, re.IGNORECASE)
    if not match:
        return None
    value = re.sub(r"\s+", " ", match.group(1)).strip(" :•|-")
    return value or None


def _parse_new_movie_card(anchor: Tag) -> dict | None:
    href = anchor.get("href")
    if not href:
        return None
    details_url = _absolute(str(href))
    if not details_url:
        return None
    card = _closest_card(anchor)
    heading = card.find(["h1", "h2", "h3", "h4", "h5", "h6"])
    raw_title = heading.get_text(" ", strip=True) if heading else card.get_text(" ", strip=True)
    raw_title = re.sub(r"\s+", " ", raw_title).strip()
    if not raw_title or raw_title.casefold() == "more":
        return None
    format_match = re.search(r"\[\s*(2D|3D)\s*\]", raw_title, re.IGNORECASE)
    movie_format = format_match.group(1).upper() if format_match else None
    title = re.sub(r"\s*\[\s*(?:2D|3D)\s*\]\s*", "", raw_title, flags=re.IGNORECASE).strip()
    text = re.sub(r"\s+", " ", card.get_text(" ", strip=True))
    # If the card title was not exposed as a heading, recover it from the
    # detail URL slug rather than returning the entire card text as a title.
    if len(title) > 130:
        slug = urlparse(details_url).path.rstrip("/").split("/")[-1]
        title = re.sub(r"[-_]+", " ", slug).strip().title()
    price_match = re.search(r"(?:৳|Tk\.?\s*)([\d,]+(?:\.\d{1,2})?)", text, re.IGNORECASE)
    return {
        "movie_id": _movie_id(details_url, title),
        "title": title,
        "format": movie_format or "Not specified",
        "rating": _label_value(text, "RATING"),
        "genre": _label_value(text, "GENRE") or "Not specified",
        "cast": _label_value(text, "CAST") or "Not listed",
        "price": price_match.group(0) if price_match else None,
        "poster_url": _image_from(card),
        "details_url": details_url,
    }


def _parse_old_movie_cards(soup: BeautifulSoup) -> list[dict]:
    movies = []
    for card in soup.select("article.card, .movie-card, .movie-item"):
        poster = card.select_one("a.poster, a[href*='/Movies/Details/'], a[href*='/movie-details/']")
        if poster is None:
            continue
        href = poster.get("href")
        title = None
        for selector in (".pt", ".movie-title", "h2", "h3", "h4", "h5"):
            node = card.select_one(selector)
            if node and node.get_text(" ", strip=True):
                title = node.get_text(" ", strip=True)
                break
        if not title:
            title = poster.get("aria-label") or poster.get_text(" ", strip=True)
        if not title:
            continue
        text = card.get_text(" ", strip=True)
        format_match = re.search(r"\b(2D|3D)\b", text, re.IGNORECASE)
        price_match = re.search(r"(?:৳|Tk\.?\s*)([\d,]+(?:\.\d{1,2})?)", text, re.IGNORECASE)
        movies.append({
            "movie_id": _movie_id(str(href) if href else None, title),
            "title": title,
            "format": format_match.group(1).upper() if format_match else "Not specified",
            "rating": None,
            "genre": _label_value(text, "GENRE") or "Not specified",
            "cast": _label_value(text, "CAST") or "Not listed",
            "price": price_match.group(0) if price_match else None,
            "poster_url": _image_from(card),
            "details_url": _absolute(str(href)) or NOW_SHOWING_URL,
        })
    return movies


def get_now_showing_movies() -> list[dict]:
    """Read current listings from the official Now Showing page."""
    soup = fetch_page(NOW_SHOWING_URL)
    movies: list[dict] = []
    seen: set[tuple[str, str]] = set()
    for anchor in soup.select("a[href*='/movie-details/'], a[href*='/Movies/Details/']"):
        movie = _parse_new_movie_card(anchor)
        if not movie:
            continue
        key = (movie["movie_id"], movie["format"])
        if key not in seen:
            seen.add(key)
            movies.append(movie)
    if not movies:
        movies = _parse_old_movie_cards(soup)
    return movies


def _schedule_card(anchor: Tag) -> Tag:
    for parent in anchor.parents:
        if not isinstance(parent, Tag) or parent.name in {"body", "html"}:
            break
        text = parent.get_text(" ", strip=True)
        if len(text) > 2200:
            continue
        if parent.find(["h1", "h2", "h3", "h4", "h5", "h6"]):
            return parent
        classes = " ".join(parent.get("class", []))
        if any(token in classes.casefold() for token in ("show", "schedule", "movie", "hall", "screen")) and len(text) > 10:
            return parent
    return anchor.parent if isinstance(anchor.parent, Tag) else anchor


def _parse_old_schedule(soup: BeautifulSoup, target_date: str) -> list[dict]:
    schedules = []
    for card in soup.select(".show-media"):
        title_element = card.select_one(".show-title")
        if not title_element:
            continue
        detail_path = title_element.get("href")
        title = title_element.get_text(" ", strip=True)
        halls = []
        for hall_row in card.select(".th-row"):
            hall_name = hall_row.select_one(".th")
            times = []
            for time_element in hall_row.select(".time"):
                times.append({
                    "time": time_element.get_text(" ", strip=True),
                    "booking_url": _absolute(time_element.get("href")) or SCHEDULE_URL,
                })
            halls.append({"hall": hall_name.get_text(" ", strip=True) if hall_name else "Blockbuster Cinemas", "showtimes": times})
        schedules.append({
            "movie_id": _movie_id(str(detail_path) if detail_path else None, title),
            "title": title,
            "format_and_genre": card.select_one(".sch-meta").get_text(" ", strip=True) if card.select_one(".sch-meta") else "",
            "poster_url": _image_from(card),
            "halls": halls,
            "date": target_date,
        })
    return schedules


def get_movie_schedule(target_date: str) -> list[dict]:
    """Read showtimes for a date. Missing hall labels are reported as generic."""
    soup = fetch_page(f"{SCHEDULE_URL}?date={target_date}")
    old = _parse_old_schedule(soup, target_date)
    if old:
        return old

    grouped: dict[tuple[str, str], dict] = {}
    for anchor in soup.find_all("a", href=True):
        time_text = anchor.get_text(" ", strip=True)
        if not TIME_RE.fullmatch(time_text):
            continue
        card = _schedule_card(anchor)
        heading = card.find(["h1", "h2", "h3", "h4", "h5", "h6"])
        title = heading.get_text(" ", strip=True) if heading else ""
        if not title:
            # Find a movie detail link within the same card and use its slug.
            detail_anchor = card.select_one("a[href*='/movie-details/'], a[href*='/Movies/Details/']")
            if detail_anchor:
                slug = urlparse(str(detail_anchor.get("href"))).path.rstrip("/").split("/")[-1]
                title = re.sub(r"[-_]+", " ", slug).title()
        if not title:
            continue
        format_match = re.search(r"\b(2D|3D)\b", card.get_text(" ", strip=True), re.IGNORECASE)
        format_text = format_match.group(1).upper() if format_match else ""
        movie_id = _movie_id(None, title)
        detail_anchor = card.select_one("a[href*='/movie-details/'], a[href*='/Movies/Details/']")
        if detail_anchor:
            movie_id = _movie_id(str(detail_anchor.get("href")), title)
        key = (movie_id, title.casefold())
        if key not in grouped:
            grouped[key] = {
                "movie_id": movie_id,
                "title": title,
                "format_and_genre": format_text,
                "poster_url": _image_from(card),
                "halls": [{"hall": "Blockbuster Cinemas", "showtimes": []}],
                "date": target_date,
            }
        booking_url = _absolute(str(anchor.get("href"))) or SCHEDULE_URL
        showtimes = grouped[key]["halls"][0]["showtimes"]
        if not any(item["time"] == time_text and item["booking_url"] == booking_url for item in showtimes):
            showtimes.append({"time": time_text, "booking_url": booking_url})

    return list(grouped.values())
