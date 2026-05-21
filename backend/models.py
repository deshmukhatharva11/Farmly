from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Text, Boolean
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    mobile_number = Column(String(15), unique=True, index=True, nullable=False)
    name = Column(String(100), default="")
    location = Column(String(200), default="Maharashtra")
    preferred_language = Column(String(5), default="mr")  # mr, hi, en
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    scans = relationship("ScanHistory", back_populates="user")
    posts = relationship("CommunityPost", back_populates="user")


class ScanHistory(Base):
    __tablename__ = "scan_history"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    image_url = Column(String(500), default="")
    detected_disease = Column(String(200), nullable=False)
    detected_disease_mr = Column(String(200), default="")
    detected_disease_hi = Column(String(200), default="")
    confidence = Column(Float, nullable=False)
    severity = Column(String(50), default="Medium")
    treatments_json = Column(Text, default="[]")
    explanation = Column(Text, default="")
    causes_json = Column(Text, default="[]")
    prevention_json = Column(Text, default="[]")
    model_name = Column(String(100), default="mock_v1")
    model_version = Column(String(20), default="1.0")
    crop_type = Column(String(100), default="")
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="scans")


class OTPStore(Base):
    __tablename__ = "otp_store"

    id = Column(Integer, primary_key=True, index=True)
    mobile_number = Column(String(15), index=True, nullable=False)
    otp_code = Column(String(6), nullable=False)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    attempts = Column(Integer, default=0)
    verified = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class CommunityPost(Base):
    __tablename__ = "community_posts"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    content = Column(Text, nullable=False)
    crop_type = Column(String(100), default="")
    image_url = Column(String(500), default="")
    likes = Column(Integer, default=0)
    comments_count = Column(Integer, default=0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="posts")


class MLModel(Base):
    """Registry of available ML models for multi-model support."""
    __tablename__ = "ml_models"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), unique=True, nullable=False)
    display_name = Column(String(200), nullable=False)
    display_name_mr = Column(String(200), default="")
    display_name_hi = Column(String(200), default="")
    version = Column(String(20), default="1.0")
    supported_crops = Column(Text, default="[]")  # JSON array
    model_path = Column(String(500), default="")
    model_type = Column(String(50), default="yolov8")  # yolov8, tflite, onnx
    accuracy = Column(Float, default=0.0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class DiseaseAdviceCache(Base):
    """Cache Gemini API responses to avoid repeated calls for same disease+language+location."""
    __tablename__ = "disease_advice_cache"

    id = Column(Integer, primary_key=True, index=True)
    disease_name = Column(String(200), nullable=False, index=True)
    language = Column(String(5), nullable=False, default="en")
    location = Column(String(200), nullable=False, default="Maharashtra")
    advice_json = Column(Text, nullable=False)  # Full JSON response from Gemini
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

