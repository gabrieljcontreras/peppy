from typing import Annotated, Optional
from uuid import UUID
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser
from app.database import get_db
from app.services.auth import create_access_token, create_refresh_token, decode_token
from app.services.user import UserService

router = APIRouter()


class UserCreate(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, description="Password must be at least 8 characters")
    display_name: Optional[str] = Field(None, max_length=100)


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class Token(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class RefreshTokenRequest(BaseModel):
    refresh_token: str


class PasswordChangeRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    current_password: str = Field(min_length=8)
    new_password: str = Field(min_length=8)


class UserResponse(BaseModel):
    id: UUID
    email: EmailStr
    display_name: Optional[str]
    timezone: str
    is_verified: bool

    class Config:
        from_attributes = True


class MessageResponse(BaseModel):
    message: str


class UserUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    display_name: str | None = Field(default=None, max_length=100)
    timezone: str | None = Field(default=None, max_length=50)

    @field_validator("display_name")
    @classmethod
    def normalize_name(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.strip()
        return value or None

    @field_validator("timezone")
    @classmethod
    def valid_timezone(cls, value: str | None) -> str:
        if value is None:
            raise ValueError("timezone cannot be null")
        try:
            ZoneInfo(value)
        except ZoneInfoNotFoundError as exc:
            raise ValueError("timezone must be a valid IANA timezone") from exc
        return value


@router.post("/register", response_model=Token, status_code=status.HTTP_201_CREATED)
async def register(
    user_data: UserCreate,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Register a new user account and return auth tokens.

    - **email**: Valid email address (will be normalized to lowercase)
    - **password**: Minimum 8 characters
    - **display_name**: Optional display name
    """
    user_service = UserService(db)

    existing_user = await user_service.get_by_email(user_data.email)
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="An account with this email already exists",
        )

    user = await user_service.create(
        email=user_data.email,
        password=user_data.password,
        display_name=user_data.display_name,
    )

    claims = {"sub": str(user.id), "ver": user.auth_version}
    access_token = create_access_token(data=claims)
    refresh_token = create_refresh_token(data=claims)

    return Token(
        access_token=access_token,
        refresh_token=refresh_token,
    )


@router.post("/login", response_model=Token)
async def login(
    credentials: UserLogin,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Authenticate and receive access + refresh tokens.

    - **email**: Registered email address
    - **password**: Account password
    """
    user_service = UserService(db)

    user = await user_service.authenticate(credentials.email, credentials.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    claims = {"sub": str(user.id), "ver": user.auth_version}
    access_token = create_access_token(data=claims)
    refresh_token = create_refresh_token(data=claims)

    return Token(
        access_token=access_token,
        refresh_token=refresh_token,
    )


@router.post("/refresh", response_model=Token)
async def refresh_tokens(
    request: RefreshTokenRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """
    Exchange a refresh token for new access + refresh tokens.

    - **refresh_token**: Valid refresh token from login
    """
    payload = decode_token(request.refresh_token)

    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if payload.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token type",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user_service = UserService(db)
    user = await user_service.get_by_id(UUID(user_id))

    if not user or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found or inactive",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if payload.get("ver", 1) != user.auth_version:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session has been revoked",
            headers={"WWW-Authenticate": "Bearer"},
        )

    claims = {"sub": str(user.id), "ver": user.auth_version}
    access_token = create_access_token(data=claims)
    refresh_token = create_refresh_token(data=claims)

    return Token(
        access_token=access_token,
        refresh_token=refresh_token,
    )


@router.get("/me", response_model=UserResponse)
async def get_current_user_info(current_user: CurrentUser):
    """
    Get the currently authenticated user's information.

    Requires a valid access token in the Authorization header.
    """
    return current_user


@router.patch("/me", response_model=UserResponse)
async def update_current_user_info(
    updates: UserUpdate,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Update the authenticated user's editable account fields."""
    return await UserService(db).update(
        current_user,
        **updates.model_dump(exclude_unset=True),
    )


@router.post("/change-password", status_code=status.HTTP_204_NO_CONTENT)
async def change_password(
    request: PasswordChangeRequest,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Change the password and revoke every existing account token."""
    try:
        await UserService(db).change_password(
            current_user,
            request.current_password,
            request.new_password,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc


@router.post("/logout", response_model=MessageResponse)
async def logout(current_user: CurrentUser):
    """
    Log out the current user.

    Note: With stateless JWTs, this is a client-side operation.
    The client should discard the tokens. This endpoint exists
    for API completeness and future token blacklisting if needed.
    """
    return MessageResponse(message="Successfully logged out")
