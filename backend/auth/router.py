from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
from models import User
from schemas import SendOTPRequest, SendOTPResponse, VerifyOTPRequest, VerifyOTPResponse
from auth.otp_service import send_otp, verify_otp
from auth.jwt_service import create_access_token

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/send-otp", response_model=SendOTPResponse)
def api_send_otp(request: SendOTPRequest, db: Session = Depends(get_db)):
    """Send OTP to the provided mobile number."""
    result = send_otp(db, request.mobile_number)
    return SendOTPResponse(**result)


@router.post("/verify-otp", response_model=VerifyOTPResponse)
def api_verify_otp(request: VerifyOTPRequest, db: Session = Depends(get_db)):
    """Verify OTP and return JWT token if valid."""
    result = verify_otp(db, request.mobile_number, request.otp)

    if not result["success"]:
        return VerifyOTPResponse(
            success=False,
            message=result["message"],
        )

    # Find or create user
    user = db.query(User).filter(User.mobile_number == request.mobile_number).first()
    is_new_user = False

    if not user:
        user = User(mobile_number=request.mobile_number)
        db.add(user)
        db.commit()
        db.refresh(user)
        is_new_user = True

    # Create JWT token
    token = create_access_token({"user_id": user.id, "mobile": user.mobile_number})

    return VerifyOTPResponse(
        success=True,
        message="Login successful",
        token=token,
        is_new_user=is_new_user,
    )
