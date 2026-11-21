from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError

from app.database import get_db
from app.core.dependencies import get_current_user

from app.models.user import User
from app.models.group_member import GroupMember
from app.models.sidequest import SideQuest
from app.models.sidequest_option import SideQuestOption
from app.models.vote import Vote

from app.schemas.vote import VoteCreate, VoteResponse


router = APIRouter(
    prefix="/sidequests",
    tags=["SideQuest Voting"],
)


def verify_voting_access(
    sidequest_id: int,
    option_id: int,
    db: Session,
    current_user: User,
):
    # Check SideQuest
    sidequest = db.get(SideQuest, sidequest_id)

    if sidequest is None:
        raise HTTPException(
            status_code=404,
            detail="SideQuest not found",
        )

    # Check group membership
    membership = (
        db.query(GroupMember)
        .filter(
            GroupMember.group_id == sidequest.group_id,
            GroupMember.user_id == current_user.id,
        )
        .first()
    )

    if membership is None:
        raise HTTPException(
            status_code=403,
            detail="You are not a member of this group",
        )

    # Check SideQuest status
    if sidequest.status != "OPEN":
        raise HTTPException(
            status_code=400,
            detail="Voting is not allowed for this SideQuest",
        )

    # Check whether the option belongs to this SideQuest
    option = (
        db.query(SideQuestOption)
        .filter(
            SideQuestOption.id == option_id,
            SideQuestOption.sidequest_id == sidequest_id,
        )
        .first()
    )

    if option is None:
        raise HTTPException(
            status_code=404,
            detail="Option not found in this SideQuest",
        )

    return sidequest


# CREATE VOTE
@router.post(
    "/{sidequest_id}/votes",
    response_model=VoteResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_vote(
    sidequest_id: int,
    vote_data: VoteCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    verify_voting_access(
        sidequest_id,
        vote_data.option_id,
        db,
        current_user,
    )

    # Check whether this user has already voted
    existing_vote = (
        db.query(Vote)
        .filter(
            Vote.sidequest_id == sidequest_id,
            Vote.user_id == current_user.id,
        )
        .first()
    )

    if existing_vote is not None:
        raise HTTPException(
            status_code=409,
            detail="You have already voted. Use the change vote endpoint.",
        )

    new_vote = Vote(
        sidequest_id=sidequest_id,
        option_id=vote_data.option_id,
        user_id=current_user.id,
    )

    try:
        db.add(new_vote)
        db.commit()
        db.refresh(new_vote)

    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail="You have already voted in this SideQuest",
        )

    return new_vote


# CHANGE VOTE
@router.put(
    "/{sidequest_id}/votes",
    response_model=VoteResponse,
)
def change_vote(
    sidequest_id: int,
    vote_data: VoteCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    verify_voting_access(
        sidequest_id,
        vote_data.option_id,
        db,
        current_user,
    )

    # Find the user's existing vote
    existing_vote = (
        db.query(Vote)
        .filter(
            Vote.sidequest_id == sidequest_id,
            Vote.user_id == current_user.id,
        )
        .first()
    )

    if existing_vote is None:
        raise HTTPException(
            status_code=404,
            detail="You have not voted in this SideQuest yet",
        )

    # Update the existing vote instead of creating another one
    existing_vote.option_id = vote_data.option_id

    try:
        db.commit()
        db.refresh(existing_vote)

    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail="Could not change your vote",
        )

    return existing_vote