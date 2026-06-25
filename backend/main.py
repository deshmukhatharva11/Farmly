import os
from dotenv import load_dotenv
load_dotenv()

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from database import init_db, SessionLocal
from auth.router import router as auth_router
from users.router import router as users_router
from scans.router import router as scans_router
from models_registry.router import router as models_router, seed_default_models
from community.router import router as community_router
from weather.router import router as weather_router
from detection.router import router as detection_router
from services.detection_routes import router as detection_v2_router

app = FastAPI(
    title="Farmly API",
    description="Backend API for Farmly - AI-powered crop disease detection",
    version="1.0.0",
)

# CORS - allow Flutter web app from any localhost port
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

from fastapi import Request

@app.middleware("http")
async def log_requests(request: Request, call_next):
    print(f"DEBUG: Incoming request: {request.method} {request.url}")
    response = await call_next(request)
    return response


# ─── Health check routes (BEFORE catch-all) ────────────────
@app.get("/", tags=["Health"])
def health_check():
    return {
        "status": "healthy",
        "app": "Farmly API",
        "version": "1.0.0",
    }


@app.get("/health", tags=["Health"])
def health():
    return {"status": "ok"}


# ─── Include routers ───────────────────────────────────────
app.include_router(auth_router)
app.include_router(users_router)
app.include_router(scans_router)
app.include_router(models_router)
app.include_router(community_router)
app.include_router(weather_router)
app.include_router(detection_router)
app.include_router(detection_v2_router)


# Global directories for uploads and outputs
uploads_dir = os.path.join(os.path.dirname(__file__), "uploads")
outputs_dir = os.path.join(os.path.dirname(__file__), "outputs")

@app.on_event("startup")
def startup():
    """Initialize database, seed data, and create directories on startup."""
    init_db()
    db = SessionLocal()
    try:
        seed_default_models(db)
    finally:
        db.close()

    # Create upload/output directories for new detection pipeline
    os.makedirs(uploads_dir, exist_ok=True)
    os.makedirs(outputs_dir, exist_ok=True)

    print("\n[Farmly] API started successfully!")
    print("[Farmly] Docs: http://localhost:8000/docs")
    print("[Farmly] Detection V2: POST /api/detect-leaf-and-disease\n")


# ─── Serve Files via standard routes ──────────────────────────
from fastapi.responses import FileResponse

@app.get("/api/outputs/{filename}")
async def get_output(filename: str):
    file_path = os.path.join(outputs_dir, filename)
    if os.path.exists(file_path):
        return FileResponse(file_path)
    return {"message": "File not found"}
    
@app.get("/api/uploads/{filename}")
async def get_upload(filename: str):
    file_path = os.path.join(uploads_dir, filename)
    if os.path.exists(file_path):
        return FileResponse(file_path)
    return {"message": "File not found"}



# ─── Serve Flutter web app (catch-all, MUST be last) ───────
from fastapi.responses import FileResponse
import os

web_build_dir = os.path.join(os.path.dirname(__file__), "..", "build", "web")

@app.get("/{full_path:path}", include_in_schema=False)
async def serve_flutter_app(full_path: str):
    if not os.path.exists(web_build_dir):
        return {"message": "API is running. Frontend not built yet."}
        
    file_path = os.path.join(web_build_dir, full_path)
    if os.path.exists(file_path) and os.path.isfile(file_path):
        return FileResponse(file_path)
        
    return FileResponse(os.path.join(web_build_dir, "index.html"))
