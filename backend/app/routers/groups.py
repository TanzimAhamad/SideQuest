import json

from pydantic import BaseModel, Field
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import and_
from sqlalchemy.orm import Session

from app.database import get_db
from app.core.dependencies import get_current_user
from app.models.user import User
from app.models.group import Group
from app.models.group_member import GroupMember
from app.models.chat_message import ChatMessage
from app.routers.chat import manager

router = APIRouter(
    prefix="/groups",
    tags=["Groups"],
)


class GroupCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)


class GroupResponse(BaseModel):
    id: int
    name: str
    created_by: int

    model_config = {"from_attributes": True}


class AddMemberRequest(BaseModel):
    user_id: int = Field(gt=0)


@router.post(
    "",
    response_model=GroupResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_group(
    group_data: GroupCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    new_group = Group(
        name=group_data.name.strip(),
        created_by=current_user.id,
    )

    db.add(new_group)

    try:
        db.flush()
        db.add(
            GroupMember(
                group_id=new_group.id,
                user_id=current_user.id,
            )
        )
        db.commit()
        db.refresh(new_group)
        return new_group
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Could not create group",
        )


@router.post(
    "/{group_id}/members",
    status_code=status.HTTP_201_CREATED,
)
def add_group_member(
    group_id: int,
    member_data: AddMemberRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Lock the group row so adding a member cannot race with ownership transfer.
    group = (
        db.query(Group)
        .filter(Group.id == group_id)
        .with_for_update()
        .first()
    )
    if group is None:
        raise HTTPException(status_code=404, detail="Group not found")

    if group.created_by != current_user.id:
        raise HTTPException(
            status_code=403,
            detail="Only the group creator can add members",
        )

    new_member = db.get(User, member_data.user_id)
    if new_member is None or not new_member.is_active:
        raise HTTPException(status_code=404, detail="User not found or inactive")

    existing = (
        db.query(GroupMember)
        .filter(
            GroupMember.group_id == group_id,
            GroupMember.user_id == member_data.user_id,
        )
        .first()
    )
    if existing:
        raise HTTPException(status_code=409, detail="User is already a member of this group")

    try:
        db.add(GroupMember(group_id=group_id, user_id=member_data.user_id))
        db.commit()
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="Could not add member",
        )

    return {
        "message": "Member added successfully",
        "group_id": group_id,
        "user_id": member_data.user_id,
    }


@router.get("/{group_id}/available-members")
def search_available_group_members(
    group_id: int,
    q: str = Query(min_length=1, max_length=50),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    group = db.get(Group, group_id)
    if group is None:
        raise HTTPException(status_code=404, detail="Group not found")

    if group.created_by != current_user.id:
        raise HTTPException(
            status_code=403,
            detail="Only the group creator can search members to add",
        )

    available_users = (
        db.query(User)
        .outerjoin(
            GroupMember,
            and_(
                GroupMember.group_id == group_id,
                GroupMember.user_id == User.id,
            ),
        )
        .filter(
            User.is_active.is_(True),
            User.id != current_user.id,
            User.username.ilike(f"{q.strip()}%"),
            GroupMember.user_id.is_(None),
        )
        .order_by(User.username.asc())
        .limit(20)
        .all()
    )

    return [
        {
            "user_id": user.id,
            "username": user.username,
            "email": user.email,
        }
        for user in available_users
    ]


@router.get("/{group_id}/members")
def get_group_members(
    group_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    group = db.get(Group, group_id)
    if group is None:
        raise HTTPException(status_code=404, detail="Group not found")

    current_membership = (
        db.query(GroupMember)
        .filter(
            GroupMember.group_id == group_id,
            GroupMember.user_id == current_user.id,
        )
        .first()
    )
    if current_membership is None:
        raise HTTPException(status_code=403, detail="You are not a member of this group")

    members = (
        db.query(User, GroupMember.joined_at)
        .join(GroupMember, User.id == GroupMember.user_id)
        .filter(GroupMember.group_id == group_id)
        .order_by(GroupMember.joined_at.asc(), User.id.asc())
        .all()
    )

    return [
        {
            "user_id": user.id,
            "username": user.username,
            "email": user.email,
            "joined_at": joined_at,
            "is_creator": user.id == group.created_by,
        }
        for user, joined_at in members
    ]


@router.delete(
    "/{group_id}/members/{user_id}",
    status_code=status.HTTP_200_OK,
)
async def remove_group_member(
    group_id: int,
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Lock the group row so a concurrent ownership transfer cannot race this action.
    group = (
        db.query(Group)
        .filter(Group.id == group_id)
        .with_for_update()
        .first()
    )
    if group is None:
        raise HTTPException(status_code=404, detail="Group not found")

    if group.created_by != current_user.id:
        raise HTTPException(
            status_code=403,
            detail="Only the group creator can remove members",
        )

    if user_id == current_user.id:
        raise HTTPException(
            status_code=400,
            detail="The creator must use Leave Group instead",
        )

    membership = (
        db.query(GroupMember)
        .filter(
            GroupMember.group_id == group_id,
            GroupMember.user_id == user_id,
        )
        .with_for_update()
        .first()
    )
    if membership is None:
        raise HTTPException(status_code=404, detail="User is not a member of this group")

    try:
        db.delete(membership)
        db.commit()
    except Exception:
        db.rollback()
        raise HTTPException(status_code=500, detail="Could not remove member")

    # Notify connected clients, then close the removed member's WebSocket.
    await manager.broadcast(
        group_id,
        json.dumps({
            "type": "group_member_removed",
            "group_id": group_id,
            "user_id": user_id,
        }),
    )
    await manager.disconnect_user(
        group_id,
        user_id,
        reason="You were removed from this group",
    )

    return {
        "message": "Member removed successfully",
        "group_id": group_id,
        "user_id": user_id,
    }


@router.delete("/{group_id}/leave")
async def leave_group(
    group_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Lock the group row to serialize creator-leave/ownership-transfer operations.
    group = (
        db.query(Group)
        .filter(Group.id == group_id)
        .with_for_update()
        .first()
    )
    if group is None:
        raise HTTPException(status_code=404, detail="Group not found")

    membership = (
        db.query(GroupMember)
        .filter(
            GroupMember.group_id == group_id,
            GroupMember.user_id == current_user.id,
        )
        .with_for_update()
        .first()
    )
    if membership is None:
        raise HTTPException(status_code=404, detail="You are not a member of this group")

    if group.created_by == current_user.id:
        # The oldest remaining member becomes the new creator.
        successor = (
            db.query(GroupMember)
            .filter(
                GroupMember.group_id == group_id,
                GroupMember.user_id != current_user.id,
            )
            .order_by(GroupMember.joined_at.asc(), GroupMember.user_id.asc())
            .with_for_update()
            .first()
        )

        if successor is None:
            # Creator is the last member: remove messages, memberships, and group.
            try:
                db.query(ChatMessage).filter(
                    ChatMessage.group_id == group_id
                ).delete(synchronize_session=False)
                db.query(GroupMember).filter(
                    GroupMember.group_id == group_id
                ).delete(synchronize_session=False)
                db.delete(group)
                db.commit()
            except Exception:
                db.rollback()
                raise HTTPException(status_code=500, detail="Could not delete the empty group")

            await manager.broadcast(
                group_id,
                json.dumps({"type": "group_deleted", "group_id": group_id}),
            )
            await manager.disconnect_group(
                group_id,
                reason="This group no longer exists",
            )
            return {
                "message": "Group deleted because you were its last member",
                "group_id": group_id,
                "user_id": current_user.id,
                "deleted": True,
                "new_creator_id": None,
            }

        new_creator_id = successor.user_id
        new_creator = db.get(User, new_creator_id)

        try:
            group.created_by = new_creator_id
            db.delete(membership)
            db.commit()
        except Exception:
            db.rollback()
            raise HTTPException(status_code=500, detail="Could not transfer group ownership")

        # Remaining members update their member list and creator permissions live.
        await manager.broadcast(
            group_id,
            json.dumps({
                "type": "group_member_left",
                "group_id": group_id,
                "user_id": current_user.id,
            }),
        )
        await manager.broadcast(
            group_id,
            json.dumps({
                "type": "group_ownership_changed",
                "group_id": group_id,
                "previous_creator_id": current_user.id,
                "new_creator_id": new_creator_id,
                "new_creator_username": new_creator.username if new_creator else None,
            }),
        )
        await manager.disconnect_user(
            group_id,
            current_user.id,
            reason="You left this group",
        )

        return {
            "message": "You left the group and ownership was transferred",
            "group_id": group_id,
            "user_id": current_user.id,
            "deleted": False,
            "new_creator_id": new_creator_id,
            "new_creator_username": new_creator.username if new_creator else None,
        }

    # Ordinary member leaves; ownership stays with the creator.
    try:
        db.delete(membership)
        db.commit()
    except Exception:
        db.rollback()
        raise HTTPException(status_code=500, detail="Could not leave group")

    await manager.broadcast(
        group_id,
        json.dumps({
            "type": "group_member_left",
            "group_id": group_id,
            "user_id": current_user.id,
        }),
    )
    await manager.disconnect_user(
        group_id,
        current_user.id,
        reason="You left this group",
    )

    return {
        "message": "You have left the group successfully",
        "group_id": group_id,
        "user_id": current_user.id,
        "deleted": False,
        "new_creator_id": group.created_by,
    }


@router.get("/mine")
def get_my_groups(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    groups = (
        db.query(Group)
        .join(GroupMember, Group.id == GroupMember.group_id)
        .filter(GroupMember.user_id == current_user.id)
        .order_by(Group.created_at.desc())
        .all()
    )

    return [
        {
            "id": group.id,
            "name": group.name,
            "created_by": group.created_by,
            "created_at": group.created_at,
        }
        for group in groups
    ]


@router.get("/{group_id}")
def get_group_details(
    group_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    group = db.get(Group, group_id)
    if group is None:
        raise HTTPException(status_code=404, detail="Group not found")

    membership = (
        db.query(GroupMember)
        .filter(
            GroupMember.group_id == group_id,
            GroupMember.user_id == current_user.id,
        )
        .first()
    )
    if membership is None:
        raise HTTPException(status_code=403, detail="You are not a member of this group")

    total_members = (
        db.query(GroupMember)
        .filter(GroupMember.group_id == group_id)
        .count()
    )

    return {
        "id": group.id,
        "name": group.name,
        "created_by": group.created_by,
        "created_at": group.created_at,
        "total_members": total_members,
    }


@router.delete("/{group_id}")
async def delete_group(
    group_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    group = (
        db.query(Group)
        .filter(Group.id == group_id)
        .with_for_update()
        .first()
    )
    if group is None:
        raise HTTPException(status_code=404, detail="Group not found")

    if group.created_by != current_user.id:
        raise HTTPException(
            status_code=403,
            detail="Only the group creator can delete this group",
        )

    try:
        db.query(ChatMessage).filter(
            ChatMessage.group_id == group_id
        ).delete(synchronize_session=False)
        db.query(GroupMember).filter(
            GroupMember.group_id == group_id
        ).delete(synchronize_session=False)
        db.delete(group)
        db.commit()
    except Exception:
        db.rollback()
        raise HTTPException(status_code=500, detail="Could not delete group")

    await manager.broadcast(
        group_id,
        json.dumps({"type": "group_deleted", "group_id": group_id}),
    )
    await manager.disconnect_group(
        group_id,
        reason="This group was deleted",
    )

    return {
        "message": "Group deleted successfully",
        "group_id": group_id,
    }
