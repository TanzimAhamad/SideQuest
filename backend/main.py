# """FastAPI application for the SideQuest backend."""
 # type: ignore[import-not-found]  # pylint: disable=import-error
from fastapi import FastAPI 

app = FastAPI(title="SideQuest API")


@app.get("/")
def root():
    return {"message": "Welcome to SideQuest API"}


@app.get("/health")
def health_check():
    return {"status": "ok"}
