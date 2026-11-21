
from pydantic import BaseModel


class RestaurantMenuItem(BaseModel):
    name: str | None = None
    category: str | None = None
    price: str | None = None
    image_url: str | None = None
    product_url: str | None = None


class RestaurantMenuResponse(BaseModel):
    source: str
    count: int
    menu: list[RestaurantMenuItem]
