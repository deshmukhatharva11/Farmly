import json
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from database import get_db
from models import MLModel
from schemas import MLModelInfo, MLModelListResponse

router = APIRouter(prefix="/models", tags=["ML Models"])


def seed_default_models(db: Session):
    """Seed default ML model entries if none exist."""
    if db.query(MLModel).count() > 0:
        return

    defaults = [
        MLModel(
            name="mock_v1",
            display_name="Mock Detection Model",
            display_name_mr="मॉक शोध मॉडेल",
            display_name_hi="मॉक डिटेक्शन मॉडल",
            version="1.0",
            supported_crops=json.dumps(["cotton", "soybean", "grape", "sugarcane"]),
            model_type="mock",
            accuracy=0.85,
            is_active=True,
        ),
        MLModel(
            name="cotton_yolov8",
            display_name="Cotton Disease YOLOv8",
            display_name_mr="कापूस रोग YOLOv8",
            display_name_hi="कपास रोग YOLOv8",
            version="1.0",
            supported_crops=json.dumps(["cotton"]),
            model_type="yolov8",
            accuracy=0.0,
            is_active=False,
        ),
        MLModel(
            name="soybean_yolov8",
            display_name="Soybean Disease YOLOv8",
            display_name_mr="सोयाबीन रोग YOLOv8",
            display_name_hi="सोयाबीन रोग YOLOv8",
            version="1.0",
            supported_crops=json.dumps(["soybean"]),
            model_type="yolov8",
            accuracy=0.0,
            is_active=False,
        ),
        MLModel(
            name="grape_yolov8",
            display_name="Grape Disease YOLOv8",
            display_name_mr="द्राक्ष रोग YOLOv8",
            display_name_hi="अंगूर रोग YOLOv8",
            version="1.0",
            supported_crops=json.dumps(["grape"]),
            model_type="yolov8",
            accuracy=0.0,
            is_active=False,
        ),
    ]

    db.add_all(defaults)
    db.commit()


@router.get("/", response_model=MLModelListResponse)
def list_models(db: Session = Depends(get_db)):
    """List all available ML models."""
    models = db.query(MLModel).filter(MLModel.is_active == True).all()
    return MLModelListResponse(models=models)


@router.get("/all", response_model=MLModelListResponse)
def list_all_models(db: Session = Depends(get_db)):
    """List all models including inactive ones."""
    models = db.query(MLModel).all()
    return MLModelListResponse(models=models)
