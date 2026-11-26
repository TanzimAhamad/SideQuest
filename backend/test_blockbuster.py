
import json

from app.integration.blockbuster import (
    get_now_showing_movies,
    get_movie_schedule
)

# Test 1: Currently listed movies
movies = get_now_showing_movies()

print("\n========== NOW SHOWING ==========\n")

print(json.dumps(
    movies,
    indent=4,
    ensure_ascii=False
))


# Test 2: Schedule for a specific date
schedule = get_movie_schedule("2026-11-12")

print("\n========== MOVIE SCHEDULE ==========\n")

print(json.dumps(
    schedule,
    indent=4,
    ensure_ascii=False
))
