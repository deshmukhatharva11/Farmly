from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime


# ─── Auth Schemas ────────────────────────────────────────────
class SendOTPRequest(BaseModel):
    mobile_number: str = Field(..., pattern=r"^[6-9]\d{9}$", description="10-digit Indian mobile number")


class SendOTPResponse(BaseModel):
    success: bool
    message: str
    message_mr: str = ""
    message_hi: str = ""
    dev_otp: Optional[str] = None


class VerifyOTPRequest(BaseModel):
    mobile_number: str = Field(..., pattern=r"^[6-9]\d{9}$")
    otp: str = Field(..., min_length=4, max_length=4)


class VerifyOTPResponse(BaseModel):
    success: bool
    message: str
    token: Optional[str] = None
    is_new_user: bool = False


class GoogleLoginRequest(BaseModel):
    email: str
    name: Optional[str] = ""
    photo_url: Optional[str] = ""


# ─── User Schemas ────────────────────────────────────────────
class UserProfile(BaseModel):
    id: int
    mobile_number: Optional[str]
    email: Optional[str]
    name: str
    location: str
    preferred_language: str
    created_at: datetime

    class Config:
        from_attributes = True


class UpdateProfileRequest(BaseModel):
    name: Optional[str] = None
    location: Optional[str] = None
    preferred_language: Optional[str] = None


# ─── Scan Schemas ────────────────────────────────────────────
class SaveScanRequest(BaseModel):
    detected_disease: str
    detected_disease_mr: str = ""
    detected_disease_hi: str = ""
    confidence: float = Field(..., ge=0.0, le=1.0)
    severity: str = "Medium"
    treatments_json: str = "[]"
    explanation: str = ""
    causes_json: str = "[]"
    prevention_json: str = "[]"
    model_name: str = "mock_v1"
    model_version: str = "1.0"
    crop_type: str = ""
    image_url: str = ""


class ScanHistoryItem(BaseModel):
    id: int
    detected_disease: str
    detected_disease_mr: str
    detected_disease_hi: str
    confidence: float
    severity: str
    treatments_json: str
    explanation: str
    causes_json: str
    prevention_json: str
    model_name: str
    crop_type: str
    image_url: str
    created_at: datetime

    class Config:
        from_attributes = True


class ScanHistoryResponse(BaseModel):
    scans: List[ScanHistoryItem]
    total: int


# ─── ML Model Schemas ───────────────────────────────────────
class MLModelInfo(BaseModel):
    id: int
    name: str
    display_name: str
    display_name_mr: str
    display_name_hi: str
    version: str
    supported_crops: str
    model_type: str
    accuracy: float
    is_active: bool

    class Config:
        from_attributes = True


class MLModelListResponse(BaseModel):
    models: List[MLModelInfo]
