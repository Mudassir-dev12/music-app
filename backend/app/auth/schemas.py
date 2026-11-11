import datetime
from typing import Optional
from pydantic import BaseModel, EmailStr, Field


class UserOut(BaseModel):
    id: str
    email: EmailStr
    display_name: Optional[str] = None
    created_at: datetime.datetime

    class Config:
        from_attributes = True


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    user: UserOut


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=10, max_length=128)
    display_name: Optional[str] = Field(None, max_length=100)
    invite_code: Optional[str] = None


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=1, max_length=128)


class RefreshRequest(BaseModel):
    refresh_token: str


class LogoutRequest(BaseModel):
    refresh_token: str


class UsageOut(BaseModel):
    today_bytes: int
    daily_limit_bytes: int
    month_global_bytes: int
    month_global_limit_bytes: int
