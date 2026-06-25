from fastapi import APIRouter, Depends, HTTPException, Header
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
from database import get_db
from models import CommunityPost, User
from auth.jwt_service import get_user_id_from_token

router = APIRouter(prefix="/community", tags=["Community"])


class CreatePostRequest(BaseModel):
    content: str
    crop_type: str = ""


class PostResponse(BaseModel):
    id: int
    user_id: int
    user_name: str = ""
    user_location: str = ""
    content: str
    crop_type: str
    image_url: str
    likes: int
    comments_count: int
    created_at: datetime

    class Config:
        from_attributes = True


class PostListResponse(BaseModel):
    posts: List[PostResponse]
    total: int


def _get_user_id_optional(authorization: str = Header(default="")) -> Optional[int]:
    """Get user_id if token provided, else None."""
    if not authorization or not authorization.startswith("Bearer "):
        return None
    token = authorization.split(" ")[1]
    return get_user_id_from_token(token)


def _get_user_id_required(authorization: str = Header(...)) -> int:
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid authorization header")
    token = authorization.split(" ")[1]
    user_id = get_user_id_from_token(token)
    if user_id is None:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    return user_id


@router.get("/posts", response_model=PostListResponse)
def list_posts(
    db: Session = Depends(get_db),
    skip: int = 0,
    limit: int = 50,
):
    """List all community posts (public)."""
    query = db.query(CommunityPost)
    total = query.count()
    posts = query.order_by(CommunityPost.created_at.desc()).offset(skip).limit(limit).all()

    result = []
    for post in posts:
        user = db.query(User).filter(User.id == post.user_id).first()
        result.append(PostResponse(
            id=post.id,
            user_id=post.user_id,
            user_name=(user.name if user and user.name else "Farmer"),
            user_location=(user.location if user and user.location else "Unknown"),
            content=post.content,
            crop_type=post.crop_type,
            image_url=post.image_url,
            likes=post.likes,
            comments_count=post.comments_count,
            created_at=post.created_at,
        ))

    return PostListResponse(posts=result, total=total)


@router.post("/posts", response_model=PostResponse)
def create_post(
    request: CreatePostRequest,
    user_id: int = Depends(_get_user_id_required),
    db: Session = Depends(get_db),
):
    """Create a new community post."""
    post = CommunityPost(
        user_id=user_id,
        content=request.content,
        crop_type=request.crop_type,
    )
    db.add(post)
    db.commit()
    db.refresh(post)

    user = db.query(User).filter(User.id == user_id).first()

    return PostResponse(
        id=post.id,
        user_id=post.user_id,
        user_name=(user.name if user and user.name else "Farmer"),
        user_location=(user.location if user and user.location else "Unknown"),
        content=post.content,
        crop_type=post.crop_type,
        image_url=post.image_url,
        likes=post.likes,
        comments_count=post.comments_count,
        created_at=post.created_at,
    )


@router.post("/posts/{post_id}/like")
def like_post(post_id: int, db: Session = Depends(get_db)):
    """Like a community post."""
    post = db.query(CommunityPost).filter(CommunityPost.id == post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    post.likes += 1
    db.commit()
    return {"success": True, "likes": post.likes}
