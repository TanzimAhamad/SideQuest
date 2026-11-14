
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
import requests

from fastapi import HTTPException, Depends, status
from sqlalchemy.orm import Session

from app.integration.blockbuster import get_movie_schedule

from app.schemas.sidequest_option import MovieOptionCreate
from app.database import get_db
from app.core.dependencies import get_current_user

from app.models.user import User
from app.models.group_member import GroupMember
from app.models.sidequest import SideQuest
from app.models.sidequest_option import SideQuestOption

from app.schemas.sidequest_option import (
    SideQuestOptionCreate,
    SideQuestOptionResponse,
)


router = APIRouter(
    prefix="/sidequests",
    tags=["SideQuest Options"],
)
@router.post(
    "/{sidequest_id}/movie-options",
    response_model=SideQuestOptionResponse,
    status_code=status.HTTP_201_CREATED,
)
def add_movie_option(
    sidequest_id: int,
    movie_data: MovieOptionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # 1. Check whether the SideQuest exists
    sidequest = db.get(SideQuest, sidequest_id)

    if sidequest is None:
        raise HTTPException(
            status_code=404,
            detail="SideQuest not found",
        )

    # 2. Check group membership
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

    # 3. Only OPEN SideQuests can accept new options
    if sidequest.status != "OPEN":
        raise HTTPException(
            status_code=400,
            detail="Cannot add options to a closed SideQuest",
        )

    # 4. Fetch Blockbuster schedule for this SideQuest's date
    try:
        schedule = get_movie_schedule(
            sidequest.proposed_date.isoformat()
        )
    except requests.RequestException:
        raise HTTPException(
            status_code=502,
            detail="Could not fetch schedule from Blockbuster Cinemas",
        )

    # 5. Find the requested movie
    selected_movie = next(
        (
            movie
            for movie in schedule
            if movie["movie_id"] == movie_data.movie_id
        ),
        None,
    )

    if selected_movie is None:
        raise HTTPException(
            status_code=404,
            detail="Movie not found in the SideQuest date's schedule",
        )

    # 6. Find the requested hall
    selected_hall = next(
        (
            hall
            for hall in selected_movie["halls"]
            if hall["hall"].strip().casefold()
            == movie_data.hall.strip().casefold()
        ),
        None,
    )

    if selected_hall is None:
        raise HTTPException(
            status_code=404,
            detail="Selected hall is not available for this movie",
        )

    # 7. Find the requested showtime
    selected_showtime = next(
        (
            showtime
            for showtime in selected_hall["showtimes"]
            if showtime["time"].strip().casefold()
            == movie_data.showtime.strip().casefold()
        ),
        None,
    )

    if selected_showtime is None:
        raise HTTPException(
            status_code=404,
            detail="Selected showtime is not available in this hall",
        )

    # 8. Save the verified movie option
    new_option = SideQuestOption(
        sidequest_id=sidequest_id,
        name=selected_movie["title"],
        category="MOVIE",
        stop_order=movie_data.stop_order,
        source="BLOCKBUSTER",
        external_id=selected_movie["movie_id"],
        estimated_cost=None,
        created_by=current_user.id,
        details={
            "movie_id": selected_movie["movie_id"],
            "movie_title": selected_movie["title"],
            "format_and_genre": selected_movie["format_and_genre"],
            "poster_url": selected_movie["poster_url"],
            "hall": selected_hall["hall"],
            "showtime": selected_showtime["time"],
            "booking_url": selected_showtime["booking_url"],
            "schedule_date": sidequest.proposed_date.isoformat(),
        },
    )

    try:
        db.add(new_option)
        db.commit()
        db.refresh(new_option)
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="Could not save movie option",
        )

    return new_option

@router.post(
    "/{sidequest_id}/options",
    response_model=SideQuestOptionResponse,
    status_code=status.HTTP_201_CREATED,
)
def add_option(
    sidequest_id: int,
    option_data: SideQuestOptionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):

    # 1. Find SideQuest
    sidequest = db.get(SideQuest, sidequest_id)

    if sidequest is None:
        raise HTTPException(
            status_code=404,
            detail="SideQuest not found",
        )

    # 2. Check group membership
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

    # 3. Only allow adding options to an open SideQuest
    if sidequest.status != "OPEN":
        raise HTTPException(
            status_code=400,
            detail="Cannot add options to a closed SideQuest",
        )

    # 4. Create option
    new_option = SideQuestOption(
        sidequest_id=sidequest_id,
        name=option_data.name,
        address=option_data.address,
        category=option_data.category,
        estimated_cost=option_data.estimated_cost,
        stop_order=option_data.stop_order,
        source="MANUAL",
        created_by=current_user.id,
    )

    try:
        db.add(new_option)
        db.commit()
        db.refresh(new_option)

    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail="Could not add option",
        )

    return new_option


@router.get(
    "/{sidequest_id}/options",
    response_model=list[SideQuestOptionResponse],
)
def get_options(
    sidequest_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):

    sidequest = db.get(SideQuest, sidequest_id)

    if sidequest is None:
        raise HTTPException(
            status_code=404,
            detail="SideQuest not found",
        )

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

    options = (
        db.query(SideQuestOption)
        .filter(
            SideQuestOption.sidequest_id == sidequest_id
        )
        .order_by(
            SideQuestOption.stop_order.asc(),
            SideQuestOption.id.asc(),
        )
        .all()
    )

    return options
