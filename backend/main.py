from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from database import init_db, SessionLocal
from auth.router import router as auth_router
from users.router import router as users_router
from scans.router import router as scans_router
from models_registry.router import router as models_router, seed_default_models
from community.router import router as community_router
from weather.router import router as weather_router
from detection.router import router as detection_router

app = FastAPI(
    title="Farmly API",
    description="Backend API for Farmly - AI-powered crop disease detection",
    version="1.0.0",
)

# CORS - allow Flutter web app from any localhost port
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
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


@app.on_event("startup")
def startup():
    """Initialize database and seed data on startup."""
    init_db()
    db = SessionLocal()
    try:
        seed_default_models(db)
    finally:
        db.close()
    print("\n🌱 Farmly API started successfully!")
    print("📖 Docs: http://localhost:8000/docs\n")


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
