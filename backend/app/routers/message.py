from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.chat_message import ChatMessage
from app.core.dependencies import get_current_user
from app.models.user import User
from fastapi import HTTPException, status
from app.models.group import Group
from app.models.group_member import GroupMember

router = APIRouter(
    prefix="/groups",
    tags=["Messages"],
)


@router.get("/{group_id}/messages")
def get_group_messages(
    group_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # 1. Check whether the group exists
    group = db.get(Group, group_id)

    if group is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Group not found",
        )

    # 2. Check whether the current user belongs to this group
    membership = (
        db.query(GroupMember)
        .filter(
            GroupMember.group_id == group_id,
            GroupMember.user_id == current_user.id,
        )
        .first()
    )

    if membership is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a member of this group",
        )

    # 3. Retrieve messages
    messages = (
        db.query(ChatMessage)
        .filter(ChatMessage.group_id == group_id)
        .order_by(ChatMessage.created_at.asc(), ChatMessage.id.asc())
        .all()
    )

    # 4. Return messages
    return [
        {
            "id": message.id,
            "group_id": message.group_id,
            "sender_id": message.sender_id,
            "message": message.message,
            "created_at": message.created_at,
        }
        for message in messages
    ]