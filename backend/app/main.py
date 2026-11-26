from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import inspect, text

from app.database import Base, engine
from app.models import User, ChatMessage

# Existing routers
from app.routers.auth import router as auth_router
from app.routers.chat import router as chat_router
from app.routers.message import router as messages_router
from app.routers.groups import router as groups_router
from app.routers.private_chat import router as private_chat_router

# SideQuest routers
from app.routers.sidequest import router as sidequests_router
from app.routers.sidequest_option import router as sidequest_options_router
from app.routers.vote import router as votes_router

# Activity routers
from app.routers.movies import router as movies_router
from app.routers.weather import router as weather_router
# Uncomment once Tanim's branch (restaurant.py & bowling.py) is merged:
# from app.routers.restaurant import router as restaurants_router
# from app.routers.bowling import router as bowling_router


def _ensure_sidequest_weather_columns() -> None:
    """Safely add weather-related columns if the sidequests table already existed."""
    inspector = inspect(engine)
    if "sidequests" not in inspector.get_table_names():
        return

    existing_cols = {col["name"] for col in inspector.get_columns("sidequests")}
    with engine.begin() as conn:
        if "location" not in existing_cols:
            conn.execute(text("ALTER TABLE sidequests ADD COLUMN location VARCHAR(150)"))
        if "weather_forecast" not in existing_cols:
            conn.execute(text("ALTER TABLE sidequests ADD COLUMN weather_forecast JSON"))


@asynccontextmanager
async def lifespan(app: FastAPI):
    try:
        Base.metadata.create_all(bind=engine)
        _ensure_sidequest_weather_columns()
        print("Database tables initialized successfully.")
    except Exception as exc:
        print(f"Warning: Could not connect to database on startup: {exc}")
        print("API is running, but database operations may fail until the database is available.")
    yield


app = FastAPI(
    title="SideQuest API",
    lifespan=lifespan,
)


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


app.include_router(auth_router)
app.include_router(messages_router)
app.include_router(groups_router)
app.include_router(chat_router)
app.include_router(private_chat_router)

app.include_router(sidequests_router)
app.include_router(sidequest_options_router)
app.include_router(votes_router)

app.include_router(movies_router)
app.include_router(weather_router)
# app.include_router(restaurants_router)
# app.include_router(bowling_router)


@app.get("/")
def root():
    return {"message": "SideQuest API is running"}


@app.get("/db-check")
def check_database():
    try:
        with engine.connect() as connection:
            connection.exec_driver_sql("SELECT 1")
        return {"database_connected": True}
    except Exception as exc:
        return {
            "database_connected": False,
            "error": str(exc),
        }