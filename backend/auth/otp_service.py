import random
from datetime import datetime, timedelta, timezone
from sqlalchemy.orm import Session
from models import OTPStore
from config import get_settings

settings = get_settings()


def generate_otp() -> str:
    """Generate a random 4-digit OTP."""
    return str(random.randint(1000, 9999))


def send_otp(db: Session, mobile_number: str) -> dict:
    """
    Generate and store (or send) an OTP for the given mobile number.
    In dev mode: OTP is logged and returned. In production: sent via SMS.
    """
    # Rate limiting: check recent attempts
    recent_otps = (
        db.query(OTPStore)
        .filter(
            OTPStore.mobile_number == mobile_number,
            OTPStore.created_at >= datetime.now(timezone.utc) - timedelta(minutes=10),
        )
        .count()
    )

    if recent_otps >= settings.otp_max_attempts:
        return {
            "success": False,
            "message": "Too many OTP requests. Please wait 10 minutes.",
            "message_mr": "खूप जास्त OTP विनंत्या. कृपया १० मिनिटे थांबा.",
            "message_hi": "बहुत अधिक OTP अनुरोध। कृपया 10 मिनट प्रतीक्षा करें।",
        }

    otp_code = generate_otp()
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=settings.otp_expire_minutes)

    # Store OTP
    otp_record = OTPStore(
        mobile_number=mobile_number,
        otp_code=otp_code,
        expires_at=expires_at,
    )
    db.add(otp_record)
    db.commit()

    # In dev mode, just log the OTP
    if settings.dev_mode:
        print(f"\n{'='*40}")
        print(f"  DEV OTP for {mobile_number}: {otp_code}")
        print(f"{'='*40}\n")

    # Future: Add SMS provider integration here
    # if settings.sms_provider == "msg91":
    #     msg91_send(mobile_number, otp_code)
    # elif settings.sms_provider == "twilio":
    #     twilio_send(mobile_number, otp_code)

    return {
        "success": True,
        "message": "OTP sent successfully",
        "message_mr": "OTP यशस्वीरित्या पाठवला",
        "message_hi": "OTP सफलतापूर्वक भेजा गया",
        # Include OTP in dev mode for easy testing
        **({"dev_otp": otp_code} if settings.dev_mode else {}),
    }


def verify_otp(db: Session, mobile_number: str, otp: str) -> dict:
    """Verify an OTP for the given mobile number."""
    otp_record = (
        db.query(OTPStore)
        .filter(
            OTPStore.mobile_number == mobile_number,
            OTPStore.verified == False,
        )
        .order_by(OTPStore.created_at.desc())
        .first()
    )

    if not otp_record:
        return {
            "success": False,
            "message": "No OTP found. Please request a new one.",
            "message_mr": "OTP सापडला नाही. कृपया नवीन मागवा.",
            "message_hi": "OTP नहीं मिला। कृपया नया अनुरोध करें।",
        }

    # Check expiry
    if otp_record.expires_at.replace(tzinfo=timezone.utc) < datetime.now(timezone.utc):
        return {
            "success": False,
            "message": "OTP has expired. Please request a new one.",
            "message_mr": "OTP ची मुदत संपली. कृपया नवीन मागवा.",
            "message_hi": "OTP समाप्त हो गया है। कृपया नया अनुरोध करें।",
        }

    # Check attempts
    otp_record.attempts += 1
    db.commit()

    if otp_record.attempts > 3:
        return {
            "success": False,
            "message": "Too many attempts. Please request a new OTP.",
            "message_mr": "खूप जास्त प्रयत्न. कृपया नवीन OTP मागवा.",
            "message_hi": "बहुत अधिक प्रयास। कृपया नया OTP अनुरोध करें।",
        }

    # Verify OTP
    if otp_record.otp_code != otp:
        return {
            "success": False,
            "message": "Invalid OTP. Please try again.",
            "message_mr": "OTP चुकीचा आहे. पुन्हा प्रयत्न करा.",
            "message_hi": "OTP गलत है। पुनः प्रयास करें।",
        }

    # Mark as verified
    otp_record.verified = True
    db.commit()

    return {"success": True, "message": "OTP verified successfully"}
