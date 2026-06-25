from fastapi import APIRouter, Depends, HTTPException, Header
from sqlalchemy.orm import Session
from database import get_db
from models import ScanHistory
from schemas import SaveScanRequest, ScanHistoryItem, ScanHistoryResponse
from auth.jwt_service import get_user_id_from_token

router = APIRouter(prefix="/scan", tags=["Scan"])


def _get_user_id(authorization: str = Header(...)) -> int:
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid authorization header")
    token = authorization.split(" ")[1]
    user_id = get_user_id_from_token(token)
    if user_id is None:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    return user_id


@router.post("/save", response_model=ScanHistoryItem)
def save_scan(
    request: SaveScanRequest,
    user_id: int = Depends(_get_user_id),
    db: Session = Depends(get_db),
):
    """Save a scan result to history."""
    scan = ScanHistory(
        user_id=user_id,
        image_url=request.image_url,
        detected_disease=request.detected_disease,
        detected_disease_mr=request.detected_disease_mr,
        detected_disease_hi=request.detected_disease_hi,
        confidence=request.confidence,
        severity=request.severity,
        treatments_json=request.treatments_json,
        explanation=request.explanation,
        causes_json=request.causes_json,
        prevention_json=request.prevention_json,
        model_name=request.model_name,
        model_version=request.model_version,
        crop_type=request.crop_type,
    )
    db.add(scan)
    db.commit()
    db.refresh(scan)
    return scan


@router.get("/history", response_model=ScanHistoryResponse)
def get_history(
    user_id: int = Depends(_get_user_id),
    db: Session = Depends(get_db),
    skip: int = 0,
    limit: int = 50,
):
    """Get the user's scan history."""
    query = db.query(ScanHistory).filter(ScanHistory.user_id == user_id)
    total = query.count()
    scans = query.order_by(ScanHistory.created_at.desc()).offset(skip).limit(limit).all()

    return ScanHistoryResponse(scans=scans, total=total)
