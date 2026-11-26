from pydantic import BaseModel, Field


class FoodpandaCatalogInfo(BaseModel):
    source: str
    city: str
    catalog_url: str
    access_mode: str
    note: str


class FoodpandaRestaurantLinkRequest(BaseModel):
    restaurant_url: str = Field(min_length=15, max_length=500)


class FoodpandaRestaurantLinkResponse(BaseModel):
    source: str
    restaurant_url: str
    valid: bool
