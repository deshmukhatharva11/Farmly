from fastapi import APIRouter, Depends, HTTPException, Header
from sqlalchemy.orm import Session
from database import get_db
from models import User
from schemas import UserProfile, UpdateProfileRequest
from auth.jwt_service import get_user_id_from_token

router = APIRouter(prefix="/user", tags=["User"])


def get_current_user(authorization: str = Header(...), db: Session = Depends(get_db)) -> User:
    """Extract and validate the current user from the JWT token."""
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid authorization header")

    token = authorization.split(" ")[1]
    user_id = get_user_id_from_token(token)

    if user_id is None:
        raise HTTPException(status_code=401, detail="Invalid or expired token")

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    return user


@router.get("/profile", response_model=UserProfile)
def get_profile(user: User = Depends(get_current_user)):
    """Get the current user's profile."""
    return user


@router.put("/profile", response_model=UserProfile)
def update_profile(
    request: UpdateProfileRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Update the current user's profile."""
    if request.name is not None:
        user.name = request.name
    if request.location is not None:
        user.location = request.location
    if request.preferred_language is not None:
        user.preferred_language = request.preferred_language

    db.commit()
    db.refresh(user)
    return user
