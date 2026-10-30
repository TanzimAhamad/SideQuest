from pydantic import BaseModel, Field
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.core.dependencies import get_current_user
from app.models.user import User
from app.models.group import Group
from app.models.group_member import GroupMember
from fastapi import Response
from app.models.chat_message import ChatMessage


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
        name=group_data.name,
        created_by=current_user.id,
    )

    db.add(new_group)

    try:
        db.flush()

        membership = GroupMember(
            group_id=new_group.id,
            user_id=current_user.id,
        )

        db.add(membership)
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
    # 1. Check whether the group exists
    group = db.get(Group, group_id)

    if group is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Group not found",
        )

    # 2. Only the group creator can add members
    if group.created_by != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the group creator can add members",
        )

    # 3. Check whether the target user exists
    new_member = db.get(User, member_data.user_id)

    if new_member is None or not new_member.is_active:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found or inactive",
        )

    # 4. Check whether the user is already a member
    existing_membership = (
        db.query(GroupMember)
        .filter(
            GroupMember.group_id == group_id,
            GroupMember.user_id == member_data.user_id,
        )
        .first()
    )

    if existing_membership:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="User is already a member of this group",
        )

    # 5. Add the new member
    membership = GroupMember(
        group_id=group_id,
        user_id=member_data.user_id,
    )

    db.add(membership)

    try:
        db.commit()
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Could not add member",
        )

    return {
        "message": "Member added successfully",
        "group_id": group_id,
        "user_id": member_data.user_id,
    }    

@router.get("/{group_id}/members")
def get_group_members(
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

    # 2. Check whether the current user is a member
    current_membership = (
        db.query(GroupMember)
        .filter(
            GroupMember.group_id == group_id,
            GroupMember.user_id == current_user.id,
        )
        .first()
    )

    if current_membership is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a member of this group",
        )

    # 3. Retrieve all group members
    members = (
        db.query(User)
        .join(
            GroupMember,
            User.id == GroupMember.user_id,
        )
        .filter(GroupMember.group_id == group_id)
        .order_by(User.id.asc())
        .all()
    )

    # 4. Return member information
    return [
        {
            "user_id": member.id,
            "username": member.username,
            "email": member.email,
        }
        for member in members
    ]

@router.delete(
    "/{group_id}/members/{user_id}",
    status_code=status.HTTP_200_OK,
)
def remove_group_member(
    group_id: int,
    user_id: int,
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

    # 2. Only the creator can remove members
    if group.created_by != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the group creator can remove members",
        )

    # 3. Creator cannot remove themselves
    if user_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Group creator cannot remove themselves",
        )

    # 4. Find the membership
    membership = (
        db.query(GroupMember)
        .filter(
            GroupMember.group_id == group_id,
            GroupMember.user_id == user_id,
        )
        .first()
    )

    if membership is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User is not a member of this group",
        )

    # 5. Remove membership
    try:
        db.delete(membership)
        db.commit()

    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Could not remove member",
        )

    return {
        "message": "Member removed successfully",
        "group_id": group_id,
        "user_id": user_id,
    }

@router.delete("/{group_id}/leave")
def leave_group(
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

    # 2. Creator cannot leave the group
    if group.created_by == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Group creator cannot leave the group",
        )

    # 3. Find current user's membership
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
            status_code=status.HTTP_404_NOT_FOUND,
            detail="You are not a member of this group",
        )

    # 4. Remove membership
    try:
        db.delete(membership)
        db.commit()

    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Could not leave group",
        )

    return {
        "message": "You have left the group successfully",
        "group_id": group_id,
        "user_id": current_user.id,
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
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Group not found",
        )

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
def delete_group(
    group_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    group = db.get(Group, group_id)

    if group is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Group not found",
        )

    if group.created_by != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the group creator can delete this group",
        )

    try:
        # Delete all chat messages of this group
        db.query(ChatMessage).filter(
            ChatMessage.group_id == group_id
        ).delete(synchronize_session=False)

        # Delete all group memberships
        db.query(GroupMember).filter(
            GroupMember.group_id == group_id
        ).delete(synchronize_session=False)

        # Delete the group
        db.delete(group)

        db.commit()

    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Could not delete group",
        )

    return {
        "message": "Group deleted successfully",
        "group_id": group_id,
    }
