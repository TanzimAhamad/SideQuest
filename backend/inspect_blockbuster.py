
import requests
from bs4 import BeautifulSoup

headers = {"User-Agent": "Mozilla/5.0"}

tests = [
    (
        "Movies",
        "https://blockbusterbd.com/Movies",
        "/Movies/Details/00928"
    ),
    (
        "Schedule",
        "https://blockbusterbd.com/Schedule?date=2026-11-12",
        "/Booking/Classic/00928"
    )
]

for name, url, target in tests:
    print(f"\n{'=' * 60}")
    print(name)

    response = requests.get(
        url,
        headers=headers,
        timeout=20
    )
    response.raise_for_status()

    soup = BeautifulSoup(response.text, "html.parser")

    link = soup.find("a", href=target)

    if not link:
        print("Target link not found!")
        continue

    print("\nTARGET LINK:")
    print(link)

    parent = link

    for level in range(1, 7):
        parent = parent.parent

        if parent is None:
            break

        print(f"\nPARENT LEVEL {level}:")
        print(parent.prettify()[:2500])
