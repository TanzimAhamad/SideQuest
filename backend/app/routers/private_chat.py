import json

from fastapi import APIRouter, Depends, HTTPException, Query, WebSocket, WebSocketDisconnect
from sqlalchemy import or_
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.database import SessionLocal, get_db
from app.models.direct_conversation import DirectConversation
from app.models.direct_message import DirectMessage
from app.models.user import User
from app.routers.chat import get_authenticated_user

router = APIRouter(tags=["Private Chats"])


class PrivateConnectionManager:
    """Tracks active sockets for each one-to-one conversation."""

    def __init__(self):
        self.active_connections: dict[int, list[tuple[int, WebSocket]]] = {}

    async def connect(self, conversation_id: int, user_id: int, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.setdefault(conversation_id, []).append((user_id, websocket))

    def disconnect(self, conversation_id: int, websocket: WebSocket):
        connections = self.active_connections.get(conversation_id, [])
        remaining = [
            (user_id, connection)
            for user_id, connection in connections
            if connection is not websocket
        ]
        if remaining:
            self.active_connections[conversation_id] = remaining
        else:
            self.active_connections.pop(conversation_id, None)

    async def broadcast(self, conversation_id: int, payload: str):
        connections = self.active_connections.get(conversation_id, []).copy()
        for _user_id, connection in connections:
            try:
                await connection.send_text(payload)
            except Exception:
                self.disconnect(conversation_id, connection)


private_manager = PrivateConnectionManager()


def _get_conversation_for_user(
    db: Session,
    conversation_id: int,
    user_id: int,
) -> DirectConversation:
    conversation = db.get(DirectConversation, conversation_id)
    if conversation is None:
        raise HTTPException(status_code=404, detail="Private conversation not found")

    if user_id not in (conversation.user1_id, conversation.user2_id):
        raise HTTPException(
            status_code=403,
            detail="You are not a participant in this conversation",
        )
    return conversation


def _message_payload(message: DirectMessage) -> dict:
    return {
        "id": message.id,
        "conversation_id": message.conversation_id,
        "sender_id": message.sender_id,
        "message": message.message,
        "created_at": message.created_at.isoformat(),
    }


@router.get("/direct/users/search")
def search_users_for_private_chat(
    q: str = Query(min_length=1, max_length=50),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Search active users by username prefix, excluding the current user."""
    query = q.strip()
    if not query:
        return []

    users = (
        db.query(User)
        .filter(
            User.is_active.is_(True),
            User.id != current_user.id,
            User.username.ilike(f"{query}%"),
        )
        .order_by(User.username.asc())
        .limit(20)
        .all()
    )

    return [
        {"user_id": user.id, "username": user.username}
        for user in users
    ]


@router.post("/direct/conversations")
def get_or_create_direct_conversation(
    other_user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Return the existing one-to-one conversation or create it once."""
    if other_user_id == current_user.id:
        raise HTTPException(status_code=400, detail="You cannot chat with yourself")

    other_user = db.get(User, other_user_id)
    if other_user is None or not other_user.is_active:
        raise HTTPException(status_code=404, detail="User not found or inactive")

    user1_id, user2_id = sorted((current_user.id, other_user_id))
    conversation = (
        db.query(DirectConversation)
        .filter(
            DirectConversation.user1_id == user1_id,
            DirectConversation.user2_id == user2_id,
        )
        .first()
    )

    created = False
    if conversation is None:
        conversation = DirectConversation(
            user1_id=user1_id,
            user2_id=user2_id,
        )
        db.add(conversation)
        try:
            db.commit()
            db.refresh(conversation)
            created = True
        except IntegrityError:
            # Another request may have created the same pair at the same time.
            db.rollback()
            conversation = (
                db.query(DirectConversation)
                .filter(
                    DirectConversation.user1_id == user1_id,
                    DirectConversation.user2_id == user2_id,
                )
                .first()
            )
            if conversation is None:
                raise HTTPException(
                    status_code=500,
                    detail="Could not create private conversation",
                )

    return {
        "id": conversation.id,
        "other_user_id": other_user.id,
        "other_username": other_user.username,
        "created_at": conversation.created_at.isoformat(),
        "created": created,
    }


@router.get("/direct/conversations")
def get_my_direct_conversations(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    conversations = (
        db.query(DirectConversation)
        .filter(
            or_(
                DirectConversation.user1_id == current_user.id,
                DirectConversation.user2_id == current_user.id,
            )
        )
        .all()
    )

    results = []
    for conversation in conversations:
        other_user_id = (
            conversation.user2_id
            if conversation.user1_id == current_user.id
            else conversation.user1_id
        )
        other_user = db.get(User, other_user_id)
        if other_user is None:
            continue

        latest_message = (
            db.query(DirectMessage)
            .filter(DirectMessage.conversation_id == conversation.id)
            .order_by(DirectMessage.created_at.desc(), DirectMessage.id.desc())
            .first()
        )

        last_activity = (
            latest_message.created_at
            if latest_message is not None
            else conversation.created_at
        )

        results.append({
            "id": conversation.id,
            "other_user_id": other_user.id,
            "other_username": other_user.username,
            "last_message": latest_message.message if latest_message else "",
            "last_sender_id": latest_message.sender_id if latest_message else None,
            "last_message_at": last_activity.isoformat(),
            "created_at": conversation.created_at.isoformat(),
        })

    results.sort(key=lambda item: item["last_message_at"], reverse=True)
    return results


@router.get("/direct/conversations/{conversation_id}/messages")
def get_direct_messages(
    conversation_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _get_conversation_for_user(db, conversation_id, current_user.id)

    messages = (
        db.query(DirectMessage)
        .filter(DirectMessage.conversation_id == conversation_id)
        .order_by(DirectMessage.created_at.asc(), DirectMessage.id.asc())
        .all()
    )
    return [_message_payload(message) for message in messages]


def _save_direct_message(
    conversation_id: int,
    sender_id: int,
    message_text: str,
) -> dict:
    db = SessionLocal()
    try:
        conversation = db.get(DirectConversation, conversation_id)
        if conversation is None or sender_id not in (
            conversation.user1_id,
            conversation.user2_id,
        ):
            raise PermissionError("You no longer have access to this conversation")

        message = DirectMessage(
            conversation_id=conversation_id,
            sender_id=sender_id,
            message=message_text,
        )
        db.add(message)
        db.commit()
        db.refresh(message)
        return _message_payload(message)
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


@router.websocket("/ws/private/{conversation_id}")
async def private_chat(websocket: WebSocket, conversation_id: int, token: str):
    user = get_authenticated_user(token)
    if user is None:
        await websocket.close(code=1008, reason="Invalid authentication")
        return

    db = SessionLocal()
    try:
        conversation = db.get(DirectConversation, conversation_id)
        is_participant = conversation is not None and user.id in (
            conversation.user1_id,
            conversation.user2_id,
        )
    finally:
        db.close()

    if not is_participant:
        await websocket.close(
            code=1008,
            reason="You are not a participant in this conversation",
        )
        return

    await private_manager.connect(conversation_id, user.id, websocket)

    try:
        while True:
            message_text = await websocket.receive_text()
            message_text = message_text.strip()

            if not message_text:
                continue

            if len(message_text) > 5000:
                await websocket.send_json({"error": "Messages cannot exceed 5000 characters"})
                continue

            try:
                saved_message = _save_direct_message(
                    conversation_id=conversation_id,
                    sender_id=user.id,
                    message_text=message_text,
                )
            except PermissionError:
                private_manager.disconnect(conversation_id, websocket)
                await websocket.close(
                    code=1008,
                    reason="You no longer have access to this conversation",
                )
                return
            except Exception:
                await websocket.send_json({"error": "Message could not be saved"})
                continue

            await private_manager.broadcast(
                conversation_id,
                json.dumps(saved_message),
            )

    except WebSocketDisconnect:
        private_manager.disconnect(conversation_id, websocket)
