from fastapi import Depends, FastAPI, HTTPException
from sqlalchemy import text
from sqlalchemy.orm import Session

# Import get_db (without parentheses)
from app.database import get_db

app = FastAPI(title="SideQuest API")


@app.get("/")
def root():
    return {"message": "SideQuest API is running"}


@app.get("/db-check")
def check_database(db: Session = Depends(get_db)):
    try:
        result = db.execute(text("SELECT 1")).scalar_one()
        return {
            "database_connected": True,
            "test_query_result": result,
        }
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Database connection failed: {str(e)}",
        )