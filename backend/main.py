from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from app.database import Base, engine
# Importing the models package registers all existing and new models with Base.
from app.models import User  # noqa: F401
from app.routers.auth import router as auth_router
from app.routers.chat import router as chat_router
from app.routers.groups import router as groups_router
from app.routers.message import router as messages_router
from app.routers.private_chat import router as private_chat_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    try:
        Base.metadata.create_all(bind=engine)
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


@app.get("/")
def root():
    return {"message": "SideQuest API is running"}


@app.get("/db-check")
def check_database():
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
        return {"database_connected": True}
    except Exception as exc:
        return {
            "database_connected": False,
            "error": str(exc),
        }
