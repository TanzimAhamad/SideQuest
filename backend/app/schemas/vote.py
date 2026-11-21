from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class VoteCreate(BaseModel):
    option_id: int = Field(gt=0)


class VoteResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    sidequest_id: int
    option_id: int
    user_id: int
    created_at: datetime
    updated_at: datetime