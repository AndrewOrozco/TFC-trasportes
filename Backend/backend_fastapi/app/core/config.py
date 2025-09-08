from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", case_sensitive=False)

    # App
    APP_NAME: str = "TFC Transportes API"
    APP_ENV: str = "development"  # development | staging | production

    # Security
    SECRET_KEY: str = Field("change_this_in_prod", min_length=16)
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # DB (usa PyMySQL)
    # Ejemplo: mysql+pymysql://root:123456@localhost:3306/tfc
    DATABASE_URL: str = "mysql+pymysql://root:123456@localhost:3306/tfc"

    # Admin seed
    ADMIN_EMAIL: str = "admin@tfc.local"
    ADMIN_PASSWORD: str = "admin123"


settings = Settings()


