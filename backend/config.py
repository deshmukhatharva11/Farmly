from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # SQLite for local dev, PostgreSQL for production (set DATABASE_URL in .env or docker-compose)
    database_url: str = "sqlite:///./farmly.db"
    secret_key: str = "farmly-super-secret-key-change-in-production-2026"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 10080  # 7 days
    otp_expire_minutes: int = 5
    otp_max_attempts: int = 5
    dev_mode: bool = True

    # Future: SMS provider config
    sms_provider: str = "mock"  # "mock", "msg91", "twilio"
    sms_api_key: str = ""

    # OpenRouter AI config
    openrouter_api_key: str = ""
    openrouter_fallback_api_key: str = ""
    ai_model: str = "google/gemini-2.5-flash"

    # Native Google Gemini API key
    gemini_api_key: str = ""

    class Config:
        env_file = ".env"


@lru_cache()
def get_settings() -> Settings:
    return Settings()
