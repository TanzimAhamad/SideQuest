from pydantic import BaseModel


class BowlingResponse(BaseModel):
    name: str | None = None
    price: str | None = None
    description: str | None = None
    image_url: str | None = None
    product_url: str | None = None
    availability: str | None = None