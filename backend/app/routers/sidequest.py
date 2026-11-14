
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.core.dependencies import get_current_user

from app.models.user import User
from app.models.group import Group
from app.models.group_member import GroupMember
from app.models.sidequest import SideQuest

from app.schemas.sidequest import (
    SideQuestCreate,
    SideQuestResponse,
)


router = APIRouter(
    prefix="/sidequests",
    tags=["SideQuests"],
)


@router.post(
    "",
    response_model=SideQuestResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_sidequest(
    sidequest_data: SideQuestCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):

    # 1. Check whether the group exists
    group = db.get(Group, sidequest_data.group_id)

    if group is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Group not found",
        )

    # 2. Check whether the current user is a group member
    membership = (
        db.query(GroupMember)
        .filter(
            GroupMember.group_id == sidequest_data.group_id,
            GroupMember.user_id == current_user.id,
        )
        .first()
    )

    if membership is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a member of this group",
        )

    # 3. Create the SideQuest object
    new_sidequest = SideQuest(
        title=sidequest_data.title,
        description=sidequest_data.description,
        activity_type=sidequest_data.activity_type,
        proposed_date=sidequest_data.proposed_date,
        proposed_time=sidequest_data.proposed_time,
        budget_min=sidequest_data.budget_min,
        budget_max=sidequest_data.budget_max,

        # Never accept creator ID from request body
        created_by=current_user.id,

        group_id=sidequest_data.group_id,
        status="OPEN",
    )

    # 4. Save to database
    try:
        db.add(new_sidequest)
        db.commit()
        db.refresh(new_sidequest)

    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Could not create SideQuest",
        )

    return new_sidequest
