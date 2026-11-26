import json
from collections import Counter
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.database import get_db
from app.models.group import Group
from app.models.group_member import GroupMember
from app.models.sidequest import SideQuest, SideQuestOption
from app.models.vote import SideQuestVote
from app.models.user import User
from app.routers.chat import manager

router = APIRouter(tags=["SideQuest"])

ALLOWED_ACTIVITIES = {"Movies", "Eating Out", "Indoor Activities"}


def require_group_member(db: Session, group_id: int, user_id: int) -> Group:
    group = db.get(Group, group_id)
    if group is None:
        raise HTTPException(status_code=404, detail="Group not found")

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
            status_code=403,
            detail="You are not a member of this group",
        )
    return group


def get_sidequest(db: Session, sidequest_id: int) -> SideQuest:
    plan = db.get(SideQuest, sidequest_id)
    if plan is None:
        raise HTTPException(status_code=404, detail="SideQuest not found")
    return plan


def require_sidequest_member(
    db: Session,
    plan: SideQuest,
    user_id: int,
) -> Group:
    return require_group_member(db, plan.group_id, user_id)


def serialize_vote_summary(db: Session, sidequest_id: int) -> tuple[list[dict], Counter]:
    vote_rows = (
        db.query(SideQuestVote, User.username)
        .join(User, User.id == SideQuestVote.user_id)
        .filter(SideQuestVote.sidequest_id == sidequest_id)
        .order_by(SideQuestVote.created_at.asc(), SideQuestVote.id.asc())
        .all()
    )

    votes = [
        {
            "id": vote.id,
            "sidequest_id": vote.sidequest_id,
            "option_id": vote.option_id,
            "activity": vote.activity,
            "user_id": vote.user_id,
            "username": username,
            "created_at": vote.created_at.isoformat() if vote.created_at else None,
        }
        for vote, username in vote_rows
    ]
    return votes, Counter(vote["option_id"] for vote in votes)


def serialize_sidequest(
    db: Session,
    plan: SideQuest,
    current_user_id: int,
) -> dict:
    group = db.get(Group, plan.group_id)
    creator = db.get(User, plan.created_by)

    option_rows = (
        db.query(SideQuestOption, User.username)
        .join(User, User.id == SideQuestOption.created_by)
        .filter(SideQuestOption.sidequest_id == plan.id)
        .order_by(SideQuestOption.created_at.asc(), SideQuestOption.id.asc())
        .all()
    )

    votes, vote_counts = serialize_vote_summary(db, plan.id)
    options = []
    for option, username in option_rows:
        options.append(
            {
                "id": option.id,
                "sidequest_id": option.sidequest_id,
                "activity": option.activity,
                "name": option.name,
                "area": option.area,
                "estimated_cost": option.estimated_cost,
                "description": option.description,
                "source_url": option.source_url,
                "source_name": option.source_name,
                "source_id": option.source_id,
                "scheduled_at": option.scheduled_at.isoformat() if option.scheduled_at else None,
                "created_by": option.created_by,
                "created_by_username": username,
                "created_at": option.created_at.isoformat() if option.created_at else None,
                "vote_count": vote_counts.get(option.id, 0),
            }
        )

    return {
        "id": plan.id,
        "group_id": plan.group_id,
        "group_name": group.name if group else "",
        "title": plan.title,
        "activities": list(plan.activities or []),
        "created_by": plan.created_by,
        "creator_username": creator.username if creator else "Unknown",
        "status": plan.status,
        "created_at": plan.created_at.isoformat() if plan.created_at else None,
        "updated_at": plan.updated_at.isoformat() if plan.updated_at else None,
        "options": options,
        "votes": votes,
        "current_user_id": current_user_id,
    }


async def broadcast_sidequest_event(
    group_id: int,
    event_type: str,
    payload: dict,
) -> None:
    event = {"type": event_type, "group_id": group_id, **payload}
    await manager.broadcast(group_id, json.dumps(event))


class SideQuestCreate(BaseModel):
    title: str = Field(min_length=1, max_length=150)
    activities: list[str] = Field(min_length=1, max_length=3)


class ActivityCreate(BaseModel):
    activity: str


class SideQuestOptionCreate(BaseModel):
    activity: str
    name: str = Field(min_length=1, max_length=200)
    area: str = Field(default="", max_length=255)
    estimated_cost: int = Field(default=0, ge=0)
    description: str = Field(default="", max_length=3000)
    source_url: Optional[str] = Field(default=None, max_length=1000)
    source_name: Optional[str] = Field(default=None, max_length=100)
    source_id: Optional[str] = Field(default=None, max_length=500)
    scheduled_at: Optional[datetime] = None


@router.get("/groups/{group_id}/sidequests/latest")
def get_latest_group_sidequest(
    group_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_group_member(db, group_id, current_user.id)

    plan = (
        db.query(SideQuest)
        .filter(SideQuest.group_id == group_id)
        .order_by(SideQuest.created_at.desc(), SideQuest.id.desc())
        .first()
    )
    if plan is None:
        return None

    return serialize_sidequest(db, plan, current_user.id)


@router.post(
    "/groups/{group_id}/sidequests",
    status_code=status.HTTP_201_CREATED,
)
async def create_group_sidequest(
    group_id: int,
    payload: SideQuestCreate,
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
    require_group_member(db, group_id, current_user.id)

    activities = list(dict.fromkeys(a.strip() for a in payload.activities))
    if not activities or any(a not in ALLOWED_ACTIVITIES for a in activities):
        raise HTTPException(
            status_code=422,
            detail="Choose Movies, Eating Out, or Indoor Activities",
        )

    existing = (
        db.query(SideQuest)
        .filter(
            SideQuest.group_id == group_id,
            SideQuest.status == "open",
        )
        .order_by(SideQuest.created_at.desc(), SideQuest.id.desc())
        .first()
    )
    if existing is not None:
        raise HTTPException(
            status_code=409,
            detail="This group already has an open SideQuest. Open the existing plan.",
        )

    plan = SideQuest(
        group_id=group_id,
        title=payload.title.strip(),
        activities=activities,
        created_by=current_user.id,
        status="open",
    )
    db.add(plan)
    try:
        db.commit()
        db.refresh(plan)
    except Exception:
        db.rollback()
        raise HTTPException(status_code=500, detail="Could not create SideQuest")

    await broadcast_sidequest_event(
        group_id,
        "sidequest_created",
        {
            "sidequest_id": plan.id,
            "title": plan.title,
            "created_by": current_user.id,
            "created_by_username": current_user.username,
        },
    )
    return serialize_sidequest(db, plan, current_user.id)


@router.get("/sidequests/{sidequest_id}")
def get_sidequest_details(
    sidequest_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    plan = get_sidequest(db, sidequest_id)
    require_sidequest_member(db, plan, current_user.id)
    return serialize_sidequest(db, plan, current_user.id)


@router.post("/sidequests/{sidequest_id}/activities")
async def add_sidequest_activity(
    sidequest_id: int,
    payload: ActivityCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    plan = get_sidequest(db, sidequest_id)
    require_sidequest_member(db, plan, current_user.id)

    activity = payload.activity.strip()
    if activity not in ALLOWED_ACTIVITIES:
        raise HTTPException(status_code=422, detail="Invalid SideQuest activity")
    if plan.status != "open":
        raise HTTPException(status_code=409, detail="This SideQuest is already finalized")

    activities = list(plan.activities or [])
    if activity not in activities:
        activities.append(activity)
        plan.activities = activities
        try:
            db.commit()
            db.refresh(plan)
        except Exception:
            db.rollback()
            raise HTTPException(status_code=500, detail="Could not add activity")

        await broadcast_sidequest_event(
            plan.group_id,
            "sidequest_activity_added",
            {
                "sidequest_id": plan.id,
                "activity": activity,
                "created_by": current_user.id,
                "created_by_username": current_user.username,
            },
        )

    return serialize_sidequest(db, plan, current_user.id)


@router.post("/sidequests/{sidequest_id}/options")
async def add_sidequest_option(
    sidequest_id: int,
    payload: SideQuestOptionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    plan = get_sidequest(db, sidequest_id)
    require_sidequest_member(db, plan, current_user.id)

    activity = payload.activity.strip()
    if activity not in ALLOWED_ACTIVITIES:
        raise HTTPException(status_code=422, detail="Invalid activity category")
    if activity not in (plan.activities or []):
        raise HTTPException(
            status_code=409,
            detail="Add this activity to the SideQuest before nominating an option",
        )
    if plan.status != "open":
        raise HTTPException(status_code=409, detail="This SideQuest is already finalized")

    name = payload.name.strip()
    if not name:
        raise HTTPException(status_code=422, detail="Option name cannot be empty")

    # Prevent the same externally identified option from being added repeatedly.
    if payload.source_id:
        existing = (
            db.query(SideQuestOption)
            .filter(
                SideQuestOption.sidequest_id == plan.id,
                SideQuestOption.activity == activity,
                SideQuestOption.source_id == payload.source_id,
            )
            .first()
        )
        if existing is not None:
            return serialize_sidequest(db, plan, current_user.id)

    option = SideQuestOption(
        sidequest_id=plan.id,
        activity=activity,
        name=name,
        area=payload.area.strip(),
        estimated_cost=payload.estimated_cost,
        description=payload.description.strip(),
        source_url=payload.source_url,
        source_name=payload.source_name,
        source_id=payload.source_id,
        scheduled_at=payload.scheduled_at,
        created_by=current_user.id,
    )
    db.add(option)
    try:
        db.commit()
        db.refresh(option)
    except Exception:
        db.rollback()
        raise HTTPException(status_code=500, detail="Could not add SideQuest option")

    await broadcast_sidequest_event(
        plan.group_id,
        "sidequest_option_added",
        {
            "sidequest_id": plan.id,
            "option_id": option.id,
            "activity": option.activity,
            "option_name": option.name,
            "created_by": current_user.id,
            "created_by_username": current_user.username,
        },
    )
    return serialize_sidequest(db, plan, current_user.id)
