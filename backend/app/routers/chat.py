
import json

import jwt
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from jwt.exceptions import InvalidTokenError
from sqlalchemy.orm import Session

from app.core.security import ALGORITHM
from app.core.dependencies import SECRET_KEY
from app.database import SessionLocal
from app.models.user import User
from app.models.chat_message import ChatMessage
from app.models.group import Group
from app.models.group_member import GroupMember


router = APIRouter()
@router.get("/chat-info", tags=["Chat"])
def chat_documentation():
    return {
        "name": "SideQuest Group Chat",
        "description": "Real-time group messaging using WebSocket",
        "connection_url": (
            "ws://127.0.0.1:8000/ws/groups/{group_id}?token={jwt_token}"
        ),
        "authentication": "JWT token required",
        "message_format": "Plain text",
        "features": [
            "Real-time messaging",
            "JWT authentication",
            "Group-based broadcasting",
            "PostgreSQL message persistence",
        ],
        "response_format": {
            "id": "Message ID",
            "group_id": "Group ID",
            "sender_id": "Sender user ID",
            "message": "Message content",
            "created_at": "Message timestamp",
        },
    }

class ConnectionManager:
    def __init__(self):
        self.active_connections: dict[int, list[WebSocket]] = {}

    async def connect(self, group_id: int, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.setdefault(group_id, []).append(websocket)

    def disconnect(self, group_id: int, websocket: WebSocket):
        connections = self.active_connections.get(group_id, [])

        if websocket in connections:
            connections.remove(websocket)

        if not connections:
            self.active_connections.pop(group_id, None)

    async def broadcast(self, group_id: int, message: str):
        connections = self.active_connections.get(group_id, []).copy()

        for connection in connections:
            try:
                await connection.send_text(message)
            except Exception:
                self.disconnect(group_id, connection)


manager = ConnectionManager()


def get_authenticated_user(token: str) -> User | None:
    db: Session = SessionLocal()

    try:
        payload = jwt.decode(
            token,
            SECRET_KEY,
            algorithms=[ALGORITHM],
        )

        user_id = int(payload.get("sub", ""))
        user = db.get(User, user_id)

        if user is None or not user.is_active:
            return None

        # Return the scalar user data needed after closing the session.
        db.expunge(user)
        return user

    except (InvalidTokenError, TypeError, ValueError):
        return None

    finally:
        db.close()

def is_group_member(group_id: int, user_id: int) -> bool:
    db: Session = SessionLocal()

    try:
        membership = (
            db.query(GroupMember)
            .filter(
                GroupMember.group_id == group_id,
                GroupMember.user_id == user_id,
            )
            .first()
        )

        return membership is not None

    finally:
        db.close()        


def save_message(group_id: int, sender_id: int, message: str) -> dict:
    db: Session = SessionLocal()

    try:
        chat_message = ChatMessage(
            group_id=group_id,
            sender_id=sender_id,
            message=message,
        )

        db.add(chat_message)
        db.commit()
        db.refresh(chat_message)

        return {
            "id": chat_message.id,
            "group_id": chat_message.group_id,
            "sender_id": chat_message.sender_id,
            "message": chat_message.message,
            "created_at": chat_message.created_at.isoformat(),
        }

    except Exception:
        db.rollback()
        raise

    finally:
        db.close()


@router.websocket("/ws/groups/{group_id}")
async def group_chat(websocket: WebSocket, group_id: int, token: str):
    user = get_authenticated_user(token)

    if user is None:
        await websocket.close(
            code=1008,
            reason="Invalid authentication",
        )
        return

    if not is_group_member(group_id, user.id):
        await websocket.close(
            code=1008,
            reason="You are not a member of this group",
        )
        return

    await manager.connect(group_id, websocket)

    try:
        while True:
            message = await websocket.receive_text()

            if not message.strip():
                continue

            try:
                saved_message = save_message(
                    group_id=group_id,
                    sender_id=user.id,
                    message=message,
                )
            except Exception:
                await websocket.send_json(
                    {"error": "Message could not be saved"}
                )
                continue

            await manager.broadcast(
                group_id,
                json.dumps(saved_message),
            )

    except WebSocketDisconnect:
        manager.disconnect(group_id, websocket)
