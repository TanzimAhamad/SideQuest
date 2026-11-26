from typing import Literal

from pydantic import BaseModel, Field, field_validator


class GameRoomCreate(BaseModel):
    game_type: Literal["friend_trivia", "would_you_rather"]
    title: str = Field(min_length=1, max_length=100)
    invited_usernames: list[str] = Field(min_length=1, max_length=19)
    max_players: int = Field(default=8, ge=2, le=20)

    @field_validator("title")
    @classmethod
    def clean_title(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Room title cannot be empty")
        return value

    @field_validator("invited_usernames")
    @classmethod
    def clean_usernames(cls, values: list[str]) -> list[str]:
        cleaned = [value.strip() for value in values if value.strip()]
        if not cleaned:
            raise ValueError("Invite at least one player by username")
        normalized = [value.casefold() for value in cleaned]
        if len(normalized) != len(set(normalized)):
            raise ValueError("The same username cannot be invited more than once")
        return cleaned


class GameUserSearchResult(BaseModel):
    username: str


class GameRoomActionResponse(BaseModel):
    message: str
    room_id: int
    status: str


class WouldYouRatherVoteRequest(BaseModel):
    choice: Literal["A", "B"]


class FriendTriviaChoiceRequest(BaseModel):
    choice: Literal["A", "B", "C", "D"]
