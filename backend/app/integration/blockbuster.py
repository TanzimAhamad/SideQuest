
import re
import requests

from bs4 import BeautifulSoup
from urllib.parse import urljoin


BASE_URL = "https://blockbusterbd.com"

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


def extract_background_image(style: str | None) -> str | None:
    """Extract image URL from CSS background-image."""

    if not style:
        return None

    match = re.search(
        r"url\(['\"]?(.*?)['\"]?\)",
        style
    )

    if match:
        return urljoin(BASE_URL, match.group(1))

    return None


def get_text(element, selector: str) -> str | None:
    """Safely extract text from a child element."""

    child = element.select_one(selector)

    if child:
        return child.get_text(" ", strip=True)

    return None


def get_now_showing_movies() -> list[dict]:
    """Retrieve currently listed movies."""

    url = f"{BASE_URL}/Movies"

    soup = fetch_page(url)

    movies = []

    for card in soup.select("article.card"):

        poster = card.select_one("a.poster")

        if not poster:
            continue

        detail_path = poster.get("href")

        movie_id = None

        if detail_path:
            match = re.search(r"/Movies/Details/(\w+)", detail_path)

            if match:
                movie_id = match.group(1)

        movie = {
            "movie_id": movie_id,
            "title": get_text(card, ".pt"),
            "format": get_text(card, ".chip.type"),
            "rating": get_text(card, ".chip.rt"),
            "genre": get_text(card, ".genre"),
            "cast": get_text(card, ".cast"),
            "price": get_text(card, ".bp"),
            "poster_url": extract_background_image(
                poster.get("style")
            ),
            "details_url": (
                urljoin(BASE_URL, detail_path)
                if detail_path else None
            )
        }

        movies.append(movie)

    return movies


def get_movie_schedule(date: str) -> list[dict]:
    """Retrieve movie schedules for a specific date."""

    url = f"{BASE_URL}/Schedule"

    soup = fetch_page(
        f"{url}?date={date}"
    )

    schedules = []

    for card in soup.select(".show-media"):

        title_element = card.select_one(".show-title")

        if not title_element:
            continue

        detail_path = title_element.get("href")

        movie_id = None

        if detail_path:
            match = re.search(
                r"/Movies/Details/(\w+)",
                detail_path
            )

            if match:
                movie_id = match.group(1)

        halls = []

        for hall_row in card.select(".th-row"):

            hall_name = get_text(hall_row, ".th")

            showtimes = []

            for time_element in hall_row.select(".time"):

                showtimes.append({
                    "time": time_element.get_text(
                        " ", strip=True
                    ),
                    "booking_url": urljoin(
                        BASE_URL,
                        time_element.get("href", "")
                    )
                })

            halls.append({
                "hall": hall_name,
                "showtimes": showtimes
            })

        schedule = {
            "movie_id": movie_id,
            "title": title_element.get_text(
                " ", strip=True
            ),
            "format_and_genre": get_text(
                card, ".sch-meta"
            ),
            "poster_url": extract_background_image(
                card.select_one(".show-poster").get("style")
            ) if card.select_one(".show-poster") else None,
            "halls": halls,
            "date": date
        }

        schedules.append(schedule)

    return schedules
