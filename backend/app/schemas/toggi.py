from pydantic import BaseModel


class ToggiProductInfo(BaseModel):
    product_id: str
    name: str
    category: str | None = None
    price_bdt: float | None = None
    price_text: str | None = None
    product_url: str
    description: str | None = None
    product_type: str = "activity"


class ToggiActivityListResponse(BaseModel):
    source: str
    venue: str
    catalog_url: str
    count: int
    pages_fetched: int
    has_more: bool
    products: list[ToggiProductInfo]
    fetched_at: str
    price_notice: str


class ToggiPackageInfo(BaseModel):
    package_id: str
    name: str
    price_bdt: float | None = None
    price_text: str | None = None
    description: str | None = None
    package_url: str
    product_type: str = "package"


class ToggiPackageListResponse(BaseModel):
    source: str
    catalog_url: str
    count: int
    packages: list[ToggiPackageInfo]
    fetched_at: str
    price_notice: str


class ToggiProductDetailsResponse(BaseModel):
    source: str
    product_id: str
    name: str
    category: str | None = None
    price_bdt: float | None = None
    price_text: str | None = None
    description: str | None = None
    product_url: str
    booking_url: str
    fetched_at: str
    price_notice: str
