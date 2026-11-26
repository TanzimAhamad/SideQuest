import random
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user
from app.database import get_db
from app.models.game_room import (
    GameRoom,
    GameRoomParticipant,
    WouldYouRatherRound,
    WouldYouRatherVote,
)
from app.models.friend_trivia import FriendTriviaRound, FriendTriviaGuess
from app.models.user import User
from app.schemas.games import (
    GameRoomCreate,
    WouldYouRatherVoteRequest,
    FriendTriviaChoiceRequest,
)

router = APIRouter(prefix="/games", tags=["Games"])

WY_R_TOTAL_ROUNDS = 10

# A small built-in question bank keeps the first playable version self-contained.
# Questions are selected on the server, so every player in a room sees the same one.
WOULD_YOU_RATHER_QUESTIONS = [
    (
        "Would you rather be able to travel to the past or visit the future?",
        "Travel to the past",
        "Visit the future",
    ),
    (
        "Would you rather speak every language or play every musical instrument?",
        "Speak every language",
        "Play every instrument",
    ),
    (
        "Would you rather explore the deepest ocean or travel into outer space?",
        "Explore the deepest ocean",
        "Travel into outer space",
    ),
    (
        "Would you rather never use social media again or never watch films and series again?",
        "Give up social media",
        "Give up films and series",
    ),
    (
        "Would you rather always arrive 10 minutes early or 20 minutes late?",
        "Always 10 minutes early",
        "Always 20 minutes late",
    ),
    (
        "Would you rather be able to talk to animals or understand every human language?",
        "Talk to animals",
        "Understand every language",
    ),
    (
        "Would you rather live beside a quiet beach or in a cabin in the mountains?",
        "Live beside a beach",
        "Live in the mountains",
    ),
    (
        "Would you rather have unlimited books or unlimited video games?",
        "Unlimited books",
        "Unlimited video games",
    ),
    (
        "Would you rather give up your phone for a month or give up the internet for a month?",
        "Give up your phone",
        "Give up the internet",
    ),
    (
        "Would you rather be able to teleport anywhere or become invisible for one hour a day?",
        "Teleport anywhere",
        "Become invisible for one hour a day",
    ),
    (
        "Would you rather have a personal chef or a personal driver?",
        "A personal chef",
        "A personal driver",
    ),
    (
        "Would you rather be famous but have no privacy or wealthy but completely unknown?",
        "Famous with no privacy",
        "Wealthy but unknown",
    ),
    (
        "Would you rather only experience summer or only experience winter?",
        "Only summer",
        "Only winter",
    ),
    (
        "Would you rather instantly master any skill or have a perfect memory?",
        "Instantly master any skill",
        "Have a perfect memory",
    ),
    (
        "Would you rather eat your favourite meal every day or never eat the same meal twice?",
        "Favourite meal every day",
        "A different meal every day",
    ),
    (
        "Would you rather be able to control the weather or control traffic?",
        "Control the weather",
        "Control traffic",
    ),
    (
        "Would you rather go on a free trip around the world or have a free home anywhere?",
        "Travel around the world",
        "Own a home anywhere",
    ),
    (
        "Would you rather never have to sleep or never have to study for an exam again?",
        "Never need to sleep",
        "Never need to study for exams",
    ),
    (
        "Would you rather have unlimited pizza or unlimited ice cream?",
        "Unlimited pizza",
        "Unlimited ice cream",
    ),
    (
        "Would you rather solve one major world problem or invent something used by everyone?",
        "Solve a major world problem",
        "Invent something used by everyone",
    ),
]


def _room_payload(db: Session, room: GameRoom, current_user_id: int) -> dict:
    participant_rows = (
        db.query(GameRoomParticipant, User)
        .join(User, User.id == GameRoomParticipant.user_id)
        .filter(GameRoomParticipant.room_id == room.id)
        .order_by(GameRoomParticipant.invited_at.asc(), User.username.asc())
        .all()
    )

    host = db.get(User, room.host_user_id)
    my_participation = next(
        (participant for participant, _user in participant_rows
         if participant.user_id == current_user_id),
        None,
    )

    accepted_count = sum(
        1 for participant, _user in participant_rows
        if participant.invitation_status == "accepted"
    )

    return {
        "id": room.id,
        "game_type": room.game_type,
        "title": room.title,
        "status": room.status,
        "max_players": room.max_players,
        "host_username": host.username if host else "Unknown",
        "is_host": room.host_user_id == current_user_id,
        "my_invitation_status": (
            my_participation.invitation_status if my_participation else None
        ),
        "participant_count": accepted_count,
        "created_at": room.created_at.isoformat() if room.created_at else None,
        "participants": [
            {
                "username": user.username,
                "role": participant.role,
                "invitation_status": participant.invitation_status,
            }
            for participant, user in participant_rows
        ],
    }


def _get_participation(
    db: Session,
    room_id: int,
    user_id: int,
) -> tuple[GameRoom, GameRoomParticipant]:
    room = db.get(GameRoom, room_id)
    if room is None:
        raise HTTPException(status_code=404, detail="Game room not found")

    participation = (
        db.query(GameRoomParticipant)
        .filter(
            GameRoomParticipant.room_id == room_id,
            GameRoomParticipant.user_id == user_id,
        )
        .first()
    )
    if participation is None or participation.invitation_status == "declined":
        raise HTTPException(status_code=403, detail="You do not have access to this game room")

    return room, participation


def _require_wyr_participant(
    db: Session,
    room_id: int,
    current_user: User,
) -> tuple[GameRoom, GameRoomParticipant]:
    room, participation = _get_participation(db, room_id, current_user.id)
    if room.game_type != "would_you_rather":
        raise HTTPException(status_code=400, detail="This room is not a Would You Rather game")
    if participation.invitation_status != "accepted":
        raise HTTPException(status_code=403, detail="Accept the game invitation before entering")
    return room, participation


def _choose_question(db: Session, room_id: int) -> tuple[str, str, str]:
    used_questions = {
        row[0]
        for row in db.query(WouldYouRatherRound.question_text)
        .filter(WouldYouRatherRound.room_id == room_id)
        .all()
    }
    available = [item for item in WOULD_YOU_RATHER_QUESTIONS if item[0] not in used_questions]
    if not available:
        available = WOULD_YOU_RATHER_QUESTIONS
    return random.choice(available)


def _would_you_rather_payload(
    db: Session,
    room: GameRoom,
    current_user: User,
) -> dict:
    accepted_rows = (
        db.query(GameRoomParticipant, User)
        .join(User, User.id == GameRoomParticipant.user_id)
        .filter(
            GameRoomParticipant.room_id == room.id,
            GameRoomParticipant.invitation_status == "accepted",
        )
        .order_by(GameRoomParticipant.role.desc(), User.username.asc())
        .all()
    )
    pending_invites = (
        db.query(GameRoomParticipant)
        .filter(
            GameRoomParticipant.room_id == room.id,
            GameRoomParticipant.invitation_status == "invited",
        )
        .count()
    )

    current_round = (
        db.query(WouldYouRatherRound)
        .filter(WouldYouRatherRound.room_id == room.id)
        .order_by(WouldYouRatherRound.round_number.desc())
        .first()
    )

    votes_by_user: dict[int, str] = {}
    option_a_votes = 0
    option_b_votes = 0
    if current_round is not None:
        vote_rows = (
            db.query(WouldYouRatherVote.user_id, WouldYouRatherVote.choice)
            .filter(WouldYouRatherVote.round_id == current_round.id)
            .all()
        )
        votes_by_user = {user_id: choice for user_id, choice in vote_rows}
        option_a_votes = sum(1 for choice in votes_by_user.values() if choice == "A")
        option_b_votes = sum(1 for choice in votes_by_user.values() if choice == "B")

    players_total = len(accepted_rows)
    votes_submitted = len(votes_by_user)
    results_revealed = (
        current_round is not None
        and players_total > 0
        and votes_submitted == players_total
    )

    round_payload = None
    if current_round is not None:
        round_payload = {
            "round_number": current_round.round_number,
            "total_rounds": WY_R_TOTAL_ROUNDS,
            "question": current_round.question_text,
            "option_a": current_round.option_a,
            "option_b": current_round.option_b,
            "status": current_round.status,
        }

    host = db.get(User, room.host_user_id)
    return {
        "room_id": room.id,
        "title": room.title,
        "game_type": room.game_type,
        "room_status": room.status,
        "host_username": host.username if host else "Unknown",
        "is_host": room.host_user_id == current_user.id,
        "participant_count": players_total,
        "max_players": room.max_players,
        "pending_invites": pending_invites,
        "current_round": round_payload,
        "votes_submitted": votes_submitted,
        "players_total": players_total,
        "my_vote": votes_by_user.get(current_user.id),
        "results_revealed": results_revealed,
        "option_a_votes": option_a_votes if results_revealed else None,
        "option_b_votes": option_b_votes if results_revealed else None,
        "option_a_percentage": round(option_a_votes * 100 / players_total, 1)
        if results_revealed else None,
        "option_b_percentage": round(option_b_votes * 100 / players_total, 1)
        if results_revealed else None,
        "players": [
            {
                "username": user.username,
                "role": participant.role,
                "has_voted": user.id in votes_by_user,
            }
            for participant, user in accepted_rows
        ],
    }


@router.get("/users/search")
def search_game_users(
    q: str = Query(min_length=1, max_length=50),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Search active users by username. User IDs are kept internal to the API."""
    query = q.strip()
    if not query:
        return []

    users = (
        db.query(User)
        .filter(
            User.is_active.is_(True),
            User.id != current_user.id,
            User.username.ilike(f"%{query}%"),
        )
        .order_by(User.username.asc())
        .limit(15)
        .all()
    )
    return [{"username": user.username} for user in users]


@router.post("/rooms", status_code=status.HTTP_201_CREATED)
def create_game_room(
    room_data: GameRoomCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    invited_usernames = [name.casefold() for name in room_data.invited_usernames]
    if current_user.username.casefold() in invited_usernames:
        raise HTTPException(status_code=400, detail="You cannot invite yourself")

    if len(invited_usernames) + 1 > room_data.max_players:
        raise HTTPException(
            status_code=400,
            detail="Maximum players must include you and every invited player",
        )

    users = (
        db.query(User)
        .filter(
            User.is_active.is_(True),
            func.lower(User.username).in_(invited_usernames),
        )
        .all()
    )
    users_by_username = {user.username.casefold(): user for user in users}
    missing = [name for name in room_data.invited_usernames
               if name.casefold() not in users_by_username]
    if missing:
        raise HTTPException(
            status_code=404,
            detail=f"User not found or inactive: {', '.join(missing)}",
        )

    room = GameRoom(
        game_type=room_data.game_type,
        title=room_data.title,
        host_user_id=current_user.id,
        max_players=room_data.max_players,
        status="lobby",
    )
    db.add(room)

    try:
        db.flush()
        db.add(
            GameRoomParticipant(
                room_id=room.id,
                user_id=current_user.id,
                role="host",
                invitation_status="accepted",
            )
        )
        for username in room_data.invited_usernames:
            invited_user = users_by_username[username.casefold()]
            db.add(
                GameRoomParticipant(
                    room_id=room.id,
                    user_id=invited_user.id,
                    role="player",
                    invitation_status="invited",
                )
            )
        db.commit()
        db.refresh(room)
    except Exception:
        db.rollback()
        raise HTTPException(status_code=500, detail="Could not create game room")

    return _room_payload(db, room, current_user.id)


@router.get("/rooms")
def get_my_game_rooms(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rooms = (
        db.query(GameRoom)
        .join(GameRoomParticipant, GameRoomParticipant.room_id == GameRoom.id)
        .filter(
            GameRoomParticipant.user_id == current_user.id,
            GameRoomParticipant.invitation_status == "accepted",
        )
        .order_by(GameRoom.created_at.desc(), GameRoom.id.desc())
        .all()
    )
    return [_room_payload(db, room, current_user.id) for room in rooms]


@router.get("/invitations")
def get_my_game_invitations(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rooms = (
        db.query(GameRoom)
        .join(GameRoomParticipant, GameRoomParticipant.room_id == GameRoom.id)
        .filter(
            GameRoomParticipant.user_id == current_user.id,
            GameRoomParticipant.invitation_status == "invited",
            GameRoom.status == "lobby",
        )
        .order_by(GameRoom.created_at.desc(), GameRoom.id.desc())
        .all()
    )
    return [_room_payload(db, room, current_user.id) for room in rooms]


@router.get("/rooms/{room_id}")
def get_game_room(
    room_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room, _participation = _get_participation(db, room_id, current_user.id)
    return _room_payload(db, room, current_user.id)


@router.post("/rooms/{room_id}/accept")
def accept_game_invitation(
    room_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = (
        db.query(GameRoom)
        .filter(GameRoom.id == room_id)
        .with_for_update()
        .first()
    )
    if room is None:
        raise HTTPException(status_code=404, detail="Game room not found")

    participation = (
        db.query(GameRoomParticipant)
        .filter(
            GameRoomParticipant.room_id == room_id,
            GameRoomParticipant.user_id == current_user.id,
        )
        .first()
    )
    if participation is None or participation.invitation_status == "declined":
        raise HTTPException(status_code=403, detail="You do not have access to this game room")
    if participation.invitation_status != "invited":
        raise HTTPException(status_code=409, detail="There is no pending invitation")
    if room.status != "lobby":
        raise HTTPException(status_code=409, detail="This game room is no longer accepting players")

    accepted_count = (
        db.query(GameRoomParticipant)
        .filter(
            GameRoomParticipant.room_id == room_id,
            GameRoomParticipant.invitation_status == "accepted",
        )
        .count()
    )
    if accepted_count >= room.max_players:
        raise HTTPException(status_code=409, detail="This game room is full")

    participation.invitation_status = "accepted"
    participation.responded_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(room)
    return _room_payload(db, room, current_user.id)


@router.post("/rooms/{room_id}/decline")
def decline_game_invitation(
    room_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room, participation = _get_participation(db, room_id, current_user.id)
    if participation.invitation_status != "invited":
        raise HTTPException(status_code=409, detail="There is no pending invitation")

    participation.invitation_status = "declined"
    participation.responded_at = datetime.now(timezone.utc)
    db.commit()
    return {"message": "Invitation declined", "room_id": room_id}


@router.get("/rooms/{room_id}/would-you-rather")
def get_would_you_rather_state(
    room_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room, _participation = _require_wyr_participant(db, room_id, current_user)
    return _would_you_rather_payload(db, room, current_user)


@router.post("/rooms/{room_id}/would-you-rather/start")
def start_would_you_rather(
    room_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = (
        db.query(GameRoom)
        .filter(GameRoom.id == room_id)
        .with_for_update()
        .first()
    )
    if room is None:
        raise HTTPException(status_code=404, detail="Game room not found")
    if room.game_type != "would_you_rather":
        raise HTTPException(status_code=400, detail="This room is not a Would You Rather game")
    if room.host_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the host can start the game")
    if room.status != "lobby":
        raise HTTPException(status_code=409, detail="This game has already started")

    pending_invites = (
        db.query(GameRoomParticipant)
        .filter(
            GameRoomParticipant.room_id == room.id,
            GameRoomParticipant.invitation_status == "invited",
        )
        .count()
    )
    if pending_invites > 0:
        raise HTTPException(
            status_code=409,
            detail="Wait until all invitations are accepted or declined before starting",
        )

    accepted_count = (
        db.query(GameRoomParticipant)
        .filter(
            GameRoomParticipant.room_id == room.id,
            GameRoomParticipant.invitation_status == "accepted",
        )
        .count()
    )
    if accepted_count < 2:
        raise HTTPException(status_code=409, detail="At least two players must join")

    question, option_a, option_b = _choose_question(db, room.id)
    db.add(
        WouldYouRatherRound(
            room_id=room.id,
            round_number=1,
            question_text=question,
            option_a=option_a,
            option_b=option_b,
            status="active",
        )
    )
    room.status = "in_progress"
    room.started_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(room)
    return _would_you_rather_payload(db, room, current_user)


@router.post("/rooms/{room_id}/would-you-rather/vote")
def submit_would_you_rather_vote(
    room_id: int,
    vote_data: WouldYouRatherVoteRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room, _participation = _require_wyr_participant(db, room_id, current_user)
    if room.status != "in_progress":
        raise HTTPException(status_code=409, detail="The game is not accepting votes right now")

    current_round = (
        db.query(WouldYouRatherRound)
        .filter(
            WouldYouRatherRound.room_id == room.id,
            WouldYouRatherRound.status == "active",
        )
        .order_by(WouldYouRatherRound.round_number.desc())
        .first()
    )
    if current_round is None:
        raise HTTPException(status_code=409, detail="There is no active question")

    existing_vote = (
        db.query(WouldYouRatherVote)
        .filter(
            WouldYouRatherVote.round_id == current_round.id,
            WouldYouRatherVote.user_id == current_user.id,
        )
        .first()
    )
    if existing_vote is not None:
        raise HTTPException(status_code=409, detail="You have already voted in this round")

    db.add(
        WouldYouRatherVote(
            round_id=current_round.id,
            user_id=current_user.id,
            choice=vote_data.choice,
        )
    )
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="You have already voted in this round")

    return _would_you_rather_payload(db, room, current_user)


@router.post("/rooms/{room_id}/would-you-rather/next")
def next_would_you_rather_round(
    room_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = (
        db.query(GameRoom)
        .filter(GameRoom.id == room_id)
        .with_for_update()
        .first()
    )
    if room is None:
        raise HTTPException(status_code=404, detail="Game room not found")
    if room.game_type != "would_you_rather":
        raise HTTPException(status_code=400, detail="This room is not a Would You Rather game")
    if room.host_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the host can move to the next question")
    if room.status != "in_progress":
        raise HTTPException(status_code=409, detail="The game is not currently in progress")

    current_round = (
        db.query(WouldYouRatherRound)
        .filter(
            WouldYouRatherRound.room_id == room.id,
            WouldYouRatherRound.status == "active",
        )
        .order_by(WouldYouRatherRound.round_number.desc())
        .first()
    )
    if current_round is None:
        raise HTTPException(status_code=409, detail="There is no active question")

    accepted_count = (
        db.query(GameRoomParticipant)
        .filter(
            GameRoomParticipant.room_id == room.id,
            GameRoomParticipant.invitation_status == "accepted",
        )
        .count()
    )
    vote_count = (
        db.query(WouldYouRatherVote)
        .filter(WouldYouRatherVote.round_id == current_round.id)
        .count()
    )
    if vote_count < accepted_count:
        raise HTTPException(
            status_code=409,
            detail="Wait until every joined player has voted",
        )

    current_round.status = "completed"
    current_round.completed_at = datetime.now(timezone.utc)

    if current_round.round_number >= WY_R_TOTAL_ROUNDS:
        room.status = "completed"
    else:
        question, option_a, option_b = _choose_question(db, room.id)
        db.add(
            WouldYouRatherRound(
                room_id=room.id,
                round_number=current_round.round_number + 1,
                question_text=question,
                option_a=option_a,
                option_b=option_b,
                status="active",
            )
        )

    db.commit()
    db.refresh(room)
    return _would_you_rather_payload(db, room, current_user)


# ---------------------------------------------------------------------------
# Friend Trivia
# Each accepted player becomes the subject for three questions. The subject
# privately selects an answer; everyone else guesses. Correct guesses earn
# one point. The host advances after all guesses have been submitted.
# ---------------------------------------------------------------------------

FRIEND_TRIVIA_QUESTIONS_PER_PLAYER = 3
FRIEND_TRIVIA_QUESTIONS = [
    (
        "Which kind of holiday would I enjoy the most?",
        "A quiet beach holiday",
        "A mountain adventure",
        "Exploring a busy city",
        "A countryside escape",
    ),
    (
        "What would I choose for a free evening?",
        "Watching a film or series",
        "Going out with friends",
        "Reading or learning something",
        "Playing games",
    ),
    (
        "Which superpower would I choose?",
        "Teleportation",
        "Reading minds",
        "Time travel",
        "Invisibility",
    ),
    (
        "Which food would I pick first?",
        "Pizza or burgers",
        "Rice-based food",
        "Desserts and sweets",
        "Something spicy",
    ),
    (
        "What type of trip suits me best?",
        "A carefully planned trip",
        "A spontaneous adventure",
        "A relaxing staycation",
        "A trip full of activities",
    ),
    (
        "Which skill would I most like to master?",
        "Playing a musical instrument",
        "Speaking many languages",
        "Cooking like a chef",
        "A sport or physical skill",
    ),
    (
        "What would I most likely buy with unexpected extra money?",
        "A new phone or gadget",
        "A trip or experience",
        "Clothes or accessories",
        "Books, courses or learning tools",
    ),
    (
        "Which weather makes me happiest?",
        "Rainy and cool",
        "Sunny and warm",
        "Cold and foggy",
        "Mild and breezy",
    ),
    (
        "What is my ideal weekend?",
        "Staying home and relaxing",
        "Meeting friends or family",
        "Travelling somewhere new",
        "Working on a personal project",
    ),
    (
        "Which movie genre would I choose?",
        "Comedy",
        "Thriller or mystery",
        "Action or adventure",
        "Romance or drama",
    ),
    (
        "If I could meet one kind of person, who would I choose?",
        "A favourite artist or actor",
        "A successful entrepreneur",
        "A scientist or inventor",
        "A historical figure",
    ),
    (
        "Which pet would I be most likely to have?",
        "A dog",
        "A cat",
        "A bird",
        "A fish or another small pet",
    ),
    (
        "What would I prefer for breakfast?",
        "A sweet breakfast",
        "A savoury breakfast",
        "A light and healthy breakfast",
        "Just tea or coffee",
    ),
    (
        "Which place would I choose to live in?",
        "A lively big city",
        "A quiet small town",
        "Near the sea",
        "Close to nature in the countryside",
    ),
    (
        "What motivates me most?",
        "Achieving a personal goal",
        "Making family proud",
        "Helping other people",
        "Learning and discovering new things",
    ),
    (
        "Which activity would I choose at a party?",
        "Dancing",
        "Talking with everyone",
        "Playing party games",
        "Finding a quiet corner with close friends",
    ),
    (
        "What would I find hardest to give up?",
        "My phone",
        "Music",
        "My favourite food",
        "The internet",
    ),
    (
        "Which kind of gift would make me happiest?",
        "Something practical",
        "Something handmade or personal",
        "An experience or trip",
        "A surprise chosen by a friend",
    ),
    (
        "How would I prefer to spend a long journey?",
        "Listening to music",
        "Watching something",
        "Talking with people",
        "Sleeping or looking outside",
    ),
    (
        "Which goal would I choose to achieve first?",
        "Travel to many countries",
        "Build a successful career",
        "Learn an impressive new skill",
        "Have more time with loved ones",
    ),
]


def _require_friend_trivia_participant(
    db: Session,
    room_id: int,
    current_user: User,
) -> tuple[GameRoom, GameRoomParticipant]:
    room, participation = _get_participation(db, room_id, current_user.id)
    if room.game_type != "friend_trivia":
        raise HTTPException(status_code=400, detail="This room is not a Friend Trivia game")
    if participation.invitation_status != "accepted":
        raise HTTPException(status_code=403, detail="Accept the game invitation before entering")
    return room, participation


def _accepted_friend_trivia_players(db: Session, room_id: int):
    return (
        db.query(GameRoomParticipant, User)
        .join(User, User.id == GameRoomParticipant.user_id)
        .filter(
            GameRoomParticipant.room_id == room_id,
            GameRoomParticipant.invitation_status == "accepted",
        )
        .order_by(GameRoomParticipant.id.asc())
        .all()
    )


def _create_friend_trivia_round(db: Session, room_id: int, round_number: int):
    players = _accepted_friend_trivia_players(db, room_id)
    if len(players) < 2:
        raise HTTPException(status_code=409, detail="At least two players must remain in the room")

    subject_index = ((round_number - 1) // FRIEND_TRIVIA_QUESTIONS_PER_PLAYER) % len(players)
    subject_user = players[subject_index][1]
    used_questions = {
        row[0]
        for row in db.query(FriendTriviaRound.question_text)
        .filter(FriendTriviaRound.room_id == room_id)
        .all()
    }
    available = [item for item in FRIEND_TRIVIA_QUESTIONS if item[0] not in used_questions]
    if not available:
        available = FRIEND_TRIVIA_QUESTIONS
    question, option_a, option_b, option_c, option_d = random.choice(available)

    db.add(
        FriendTriviaRound(
            room_id=room_id,
            round_number=round_number,
            subject_user_id=subject_user.id,
            question_text=question,
            option_a=option_a,
            option_b=option_b,
            option_c=option_c,
            option_d=option_d,
            status="answering",
        )
    )


def _friend_trivia_payload(db: Session, room: GameRoom, current_user: User) -> dict:
    players = _accepted_friend_trivia_players(db, room.id)
    pending_invites = (
        db.query(GameRoomParticipant)
        .filter(
            GameRoomParticipant.room_id == room.id,
            GameRoomParticipant.invitation_status == "invited",
        )
        .count()
    )
    current_round = (
        db.query(FriendTriviaRound)
        .filter(FriendTriviaRound.room_id == room.id)
        .order_by(FriendTriviaRound.round_number.desc())
        .first()
    )

    guesses_by_user = {}
    scores = {user.id: 0 for _participant, user in players}
    if current_round is not None:
        guesses = (
            db.query(FriendTriviaGuess)
            .filter(FriendTriviaGuess.round_id == current_round.id)
            .all()
        )
        guesses_by_user = {guess.user_id: guess for guess in guesses}

        score_rows = (
            db.query(FriendTriviaGuess.user_id, func.count(FriendTriviaGuess.id))
            .join(FriendTriviaRound, FriendTriviaRound.id == FriendTriviaGuess.round_id)
            .filter(
                FriendTriviaRound.room_id == room.id,
                FriendTriviaGuess.is_correct.is_(True),
            )
            .group_by(FriendTriviaGuess.user_id)
            .all()
        )
        scores.update({user_id: int(score) for user_id, score in score_rows})

    subject = None
    current_round_payload = None
    results_revealed = current_round is not None and current_round.status == "completed"
    guessers_total = max(len(players) - 1, 0)
    guesses_submitted = len(guesses_by_user)

    if current_round is not None:
        subject = db.get(User, current_round.subject_user_id)
        is_subject = current_round.subject_user_id == current_user.id
        can_see_answer = is_subject or results_revealed
        options = [
            {"choice": "A", "text": current_round.option_a},
            {"choice": "B", "text": current_round.option_b},
            {"choice": "C", "text": current_round.option_c},
            {"choice": "D", "text": current_round.option_d},
        ]
        current_round_payload = {
            "round_number": current_round.round_number,
            "total_rounds": len(players) * FRIEND_TRIVIA_QUESTIONS_PER_PLAYER,
            "subject_username": subject.username if subject else "Unknown",
            "question": current_round.question_text,
            "options": options,
            "phase": current_round.status,
            "is_subject": is_subject,
            "my_answer": current_round.correct_choice if is_subject else None,
            "my_guess": (
                guesses_by_user[current_user.id].choice
                if current_user.id in guesses_by_user else None
            ),
            "correct_choice": current_round.correct_choice if can_see_answer else None,
            "correct_answer": (
                dict((item["choice"], item["text"]) for item in options).get(current_round.correct_choice)
                if can_see_answer and current_round.correct_choice else None
            ),
            "results_revealed": results_revealed,
        }

    player_payload = []
    for participant, user in players:
        player_guess = guesses_by_user.get(user.id)
        player_payload.append(
            {
                "username": user.username,
                "is_subject": current_round is not None and user.id == current_round.subject_user_id,
                "has_answered": (
                    current_round is not None
                    and user.id == current_round.subject_user_id
                    and current_round.correct_choice is not None
                ),
                "has_guessed": player_guess is not None,
                "guess_correct": player_guess.is_correct if player_guess is not None else None,
                "score": scores.get(user.id, 0),
            }
        )

    host = db.get(User, room.host_user_id)
    leaderboard = sorted(
        [
            {"username": user.username, "score": scores.get(user.id, 0)}
            for _participant, user in players
        ],
        key=lambda item: (-item["score"], item["username"].casefold()),
    )

    return {
        "room_id": room.id,
        "title": room.title,
        "game_type": room.game_type,
        "room_status": room.status,
        "host_username": host.username if host else "Unknown",
        "is_host": room.host_user_id == current_user.id,
        "participant_count": len(players),
        "max_players": room.max_players,
        "pending_invites": pending_invites,
        "players_total": len(players),
        "guessers_total": guessers_total,
        "guesses_submitted": guesses_submitted,
        "current_round": current_round_payload,
        "results_revealed": results_revealed,
        "players": player_payload,
        "leaderboard": leaderboard,
    }


@router.get("/rooms/{room_id}/friend-trivia")
def get_friend_trivia_state(
    room_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room, _participation = _require_friend_trivia_participant(db, room_id, current_user)
    return _friend_trivia_payload(db, room, current_user)


@router.post("/rooms/{room_id}/friend-trivia/start")
def start_friend_trivia(
    room_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = db.query(GameRoom).filter(GameRoom.id == room_id).with_for_update().first()
    if room is None:
        raise HTTPException(status_code=404, detail="Game room not found")
    if room.game_type != "friend_trivia":
        raise HTTPException(status_code=400, detail="This room is not a Friend Trivia game")
    if room.host_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the host can start the game")
    if room.status != "lobby":
        raise HTTPException(status_code=409, detail="This game has already started")

    pending_invites = (
        db.query(GameRoomParticipant)
        .filter(
            GameRoomParticipant.room_id == room.id,
            GameRoomParticipant.invitation_status == "invited",
        )
        .count()
    )
    if pending_invites:
        raise HTTPException(
            status_code=409,
            detail="Wait until all invitations are accepted or declined before starting",
        )

    accepted_count = (
        db.query(GameRoomParticipant)
        .filter(
            GameRoomParticipant.room_id == room.id,
            GameRoomParticipant.invitation_status == "accepted",
        )
        .count()
    )
    if accepted_count < 2:
        raise HTTPException(status_code=409, detail="At least two players must join")

    _create_friend_trivia_round(db, room.id, 1)
    room.status = "in_progress"
    room.started_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(room)
    return _friend_trivia_payload(db, room, current_user)


@router.post("/rooms/{room_id}/friend-trivia/answer")
def submit_friend_trivia_answer(
    room_id: int,
    answer_data: FriendTriviaChoiceRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room, _participation = _require_friend_trivia_participant(db, room_id, current_user)
    if room.status != "in_progress":
        raise HTTPException(status_code=409, detail="The game is not in progress")

    current_round = (
        db.query(FriendTriviaRound)
        .filter(FriendTriviaRound.room_id == room.id)
        .order_by(FriendTriviaRound.round_number.desc())
        .with_for_update()
        .first()
    )
    if current_round is None or current_round.status != "answering":
        raise HTTPException(status_code=409, detail="The subject's answer has already been submitted")
    if current_round.subject_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the selected player can answer this question")

    current_round.correct_choice = answer_data.choice
    current_round.status = "guessing"
    db.commit()
    return _friend_trivia_payload(db, room, current_user)


@router.post("/rooms/{room_id}/friend-trivia/guess")
def submit_friend_trivia_guess(
    room_id: int,
    guess_data: FriendTriviaChoiceRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room, _participation = _require_friend_trivia_participant(db, room_id, current_user)
    if room.status != "in_progress":
        raise HTTPException(status_code=409, detail="The game is not in progress")

    current_round = (
        db.query(FriendTriviaRound)
        .filter(FriendTriviaRound.room_id == room.id)
        .order_by(FriendTriviaRound.round_number.desc())
        .with_for_update()
        .first()
    )
    if current_round is None or current_round.status != "guessing":
        raise HTTPException(status_code=409, detail="Wait until the subject submits an answer")
    if current_round.subject_user_id == current_user.id:
        raise HTTPException(status_code=403, detail="The subject cannot guess their own answer")

    existing = (
        db.query(FriendTriviaGuess)
        .filter(
            FriendTriviaGuess.round_id == current_round.id,
            FriendTriviaGuess.user_id == current_user.id,
        )
        .first()
    )
    if existing is not None:
        raise HTTPException(status_code=409, detail="You have already guessed in this round")

    db.add(
        FriendTriviaGuess(
            round_id=current_round.id,
            user_id=current_user.id,
            choice=guess_data.choice,
        )
    )
    try:
        db.flush()
        expected_guesses = max(
            db.query(GameRoomParticipant)
            .filter(
                GameRoomParticipant.room_id == room.id,
                GameRoomParticipant.invitation_status == "accepted",
            )
            .count() - 1,
            0,
        )
        submitted_guesses = (
            db.query(FriendTriviaGuess)
            .filter(FriendTriviaGuess.round_id == current_round.id)
            .count()
        )
        if submitted_guesses >= expected_guesses:
            all_guesses = (
                db.query(FriendTriviaGuess)
                .filter(FriendTriviaGuess.round_id == current_round.id)
                .all()
            )
            for guess in all_guesses:
                guess.is_correct = guess.choice == current_round.correct_choice
            current_round.status = "completed"
            current_round.completed_at = datetime.now(timezone.utc)
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="You have already guessed in this round")

    return _friend_trivia_payload(db, room, current_user)


@router.post("/rooms/{room_id}/friend-trivia/next")
def next_friend_trivia_round(
    room_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = db.query(GameRoom).filter(GameRoom.id == room_id).with_for_update().first()
    if room is None:
        raise HTTPException(status_code=404, detail="Game room not found")
    if room.game_type != "friend_trivia":
        raise HTTPException(status_code=400, detail="This room is not a Friend Trivia game")
    if room.host_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the host can move to the next question")
    if room.status != "in_progress":
        raise HTTPException(status_code=409, detail="The game is not currently in progress")

    current_round = (
        db.query(FriendTriviaRound)
        .filter(FriendTriviaRound.room_id == room.id)
        .order_by(FriendTriviaRound.round_number.desc())
        .with_for_update()
        .first()
    )
    if current_round is None or current_round.status != "completed":
        raise HTTPException(status_code=409, detail="Wait until every player has guessed")

    players_count = (
        db.query(GameRoomParticipant)
        .filter(
            GameRoomParticipant.room_id == room.id,
            GameRoomParticipant.invitation_status == "accepted",
        )
        .count()
    )
    total_rounds = players_count * FRIEND_TRIVIA_QUESTIONS_PER_PLAYER
    if current_round.round_number >= total_rounds:
        room.status = "completed"
    else:
        _create_friend_trivia_round(db, room.id, current_round.round_number + 1)

    db.commit()
    db.refresh(room)
    return _friend_trivia_payload(db, room, current_user)
