from pydantic_settings import BaseSettings
from pydantic import model_validator
from functools import lru_cache


_DEFAULT_SECRET_KEY = "CHANGE-ME-IN-PRODUCTION"
_DEFAULT_ENCRYPTION_KEY = "CHANGE-ME-IN-PRODUCTION"


class Settings(BaseSettings):
    app_name: str = "Peppy API"
    debug: bool = False

    # Database
    database_url: str = "postgresql+asyncpg://localhost:5432/peppy"

    # Auth
    secret_key: str = _DEFAULT_SECRET_KEY
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 7

    # Encryption (for OAuth tokens, PHI at rest)
    encryption_key: str = _DEFAULT_ENCRYPTION_KEY

    # Redis
    redis_url: str = "redis://localhost:6379/0"

    # External APIs
    oura_client_id: str = ""
    oura_client_secret: str = ""
    whoop_client_id: str = ""
    whoop_client_secret: str = ""

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"

    @model_validator(mode="after")
    def check_production_secrets(self):
        if self.debug:
            return self
        errors = []
        if self.secret_key == _DEFAULT_SECRET_KEY:
            errors.append("SECRET_KEY must be set via environment variable")
        if self.encryption_key == _DEFAULT_ENCRYPTION_KEY:
            errors.append("ENCRYPTION_KEY must be set via environment variable")
        if errors:
            raise ValueError(
                f"Insecure configuration for production: {'; '.join(errors)}"
            )
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
