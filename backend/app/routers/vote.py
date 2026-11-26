
from collections import Counter
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.database import get_db
from app.models.sidequest import SideQuestOption
from app.models.user import User
from app.models.vote import SideQuestVote
from app.routers.sidequests import (
    broadcast_sidequest_event,
    get_sidequest,
    require_sidequest_member,
    serialize_sidequest,
)

router = APIRouter(tags=["SideQuest Voting"])


class VoteCreate(BaseModel):
    option_id: int = Field(gt=0)


@router.post("/sidequests/{sidequest_id}/votes")
async def vote_for_sidequest_option(
    sidequest_id: int,
    payload: VoteCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Each member can have only one vote per entire SideQuest.

    Members can change their existing vote to any option,
    including options belonging to different activities.
    """

    plan = get_sidequest(db, sidequest_id)

    require_sidequest_member(db, plan, current_user.id)

    if plan.status != "open":
        raise HTTPException(
            status_code=409,
            detail="Voting is closed for this SideQuest",
        )

    # Verify that the selected option belongs to this SideQuest.
    option = (
        db.query(SideQuestOption)
        .filter(
            SideQuestOption.id == payload.option_id,
            SideQuestOption.sidequest_id == plan.id,
        )
        .first()
    )

    if option is None:
        raise HTTPException(
            status_code=404,
            detail="Voting option not found",
        )

    # IMPORTANT:
    # Search using SideQuest ID and User ID only.
    # Do not filter by activity.
    existing_vote = (
        db.query(SideQuestVote)
        .filter(
            SideQuestVote.sidequest_id == plan.id,
            SideQuestVote.user_id == current_user.id,
        )
        .first()
    )

    try:
        if existing_vote is None:
            # First vote in this entire SideQuest.
            new_vote = SideQuestVote(
                sidequest_id=plan.id,
                option_id=option.id,
                activity=option.activity,
                user_id=current_user.id,
            )

            db.add(new_vote)

        else:
            # Update the existing vote.
            # This also allows changing preferences.
            existing_vote.option_id = option.id
            existing_vote.activity = option.activity
            existing_vote.created_at = datetime.now(timezone.utc)

        db.commit()

    except IntegrityError:
        db.rollback()

        raise HTTPException(
            status_code=409,
            detail="You have already voted in this SideQuest. Please refresh and try again.",
        )

    except Exception:
        db.rollback()

        raise HTTPException(
            status_code=500,
            detail="Could not record your vote",
        )

    # Notify all group members about the updated vote.
    await broadcast_sidequest_event(
        plan.group_id,
        "sidequest_vote_updated",
        {
            "sidequest_id": plan.id,
            "option_id": option.id,
            "activity": option.activity,
            "created_by": current_user.id,
            "created_by_username": current_user.username,
        },
    )

    return serialize_sidequest(db, plan, current_user.id)


@router.post("/sidequests/{sidequest_id}/finalize")
async def finalize_sidequest(
    sidequest_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Finalize voting when the entire SideQuest has one
    clear winning option across all activities.
    """

    plan = get_sidequest(db, sidequest_id)

    require_sidequest_member(db, plan, current_user.id)

    if plan.status == "finalized":
        return serialize_sidequest(db, plan, current_user.id)

    # Retrieve all options in this SideQuest.
    options = (
        db.query(SideQuestOption)
        .filter(
            SideQuestOption.sidequest_id == plan.id
        )
        .all()
    )

    if not options:
        raise HTTPException(
            status_code=409,
            detail="No options have been nominated for this SideQuest",
        )

    # Retrieve all current votes.
    votes = (
        db.query(SideQuestVote)
        .filter(
            SideQuestVote.sidequest_id == plan.id
        )
        .all()
    )

    if not votes:
        raise HTTPException(
            status_code=409,
            detail="No votes have been submitted for this SideQuest",
        )

    # Count votes across ALL activities.
    counts = Counter(
        vote.option_id for vote in votes
    )

    highest = max(counts.values())

    winners = [
        option_id
        for option_id, count in counts.items()
        if count == highest
    ]

    # Do not finalize if multiple options have equal votes.
    if len(winners) != 1:
        raise HTTPException(
            status_code=409,
            detail="There is a tie. Voting must continue.",
        )

    # A single winning option exists.
    plan.status = "finalized"

    try:
        db.commit()
        db.refresh(plan)

    except Exception:
        db.rollback()

        raise HTTPException(
            status_code=500,
            detail="Could not finalize SideQuest",
        )

    # Notify all group members.
    await broadcast_sidequest_event(
        plan.group_id,
        "sidequest_finalized",
        {
            "sidequest_id": plan.id,
            "created_by": current_user.id,
            "created_by_username": current_user.username,
        },
    )

    return serialize_sidequest(db, plan, current_user.id)
