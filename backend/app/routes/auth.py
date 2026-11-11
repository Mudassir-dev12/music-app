from fastapi import APIRouter, Depends, Request, Response, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.auth.deps import get_client_ip
from app.auth.schemas import (
    LoginRequest,
    LogoutRequest,
    RefreshRequest,
    RegisterRequest,
    TokenPair,
)
from app.auth.service import AuthService
from app.db.session import get_db_session

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post(
    "/register",
    response_model=TokenPair,
    status_code=status.HTTP_201_CREATED,
)
async def register(
    req: RegisterRequest,
    request: Request,
    db: AsyncSession = Depends(get_db_session),
):
    service = AuthService(db)
    client_ip = get_client_ip(request)
    ua = request.headers.get("user-agent")
    return await service.register(req, client_ip=client_ip, user_agent=ua)


@router.post(
    "/login",
    response_model=TokenPair,
    status_code=status.HTTP_200_OK,
)
async def login(
    req: LoginRequest,
    request: Request,
    db: AsyncSession = Depends(get_db_session),
):
    service = AuthService(db)
    client_ip = get_client_ip(request)
    ua = request.headers.get("user-agent")
    return await service.login(req, client_ip=client_ip, user_agent=ua)


@router.post(
    "/refresh",
    response_model=TokenPair,
    status_code=status.HTTP_200_OK,
)
async def refresh(
    req: RefreshRequest,
    request: Request,
    db: AsyncSession = Depends(get_db_session),
):
    service = AuthService(db)
    client_ip = get_client_ip(request)
    ua = request.headers.get("user-agent")
    return await service.refresh(
        req.refresh_token, client_ip=client_ip, user_agent=ua
    )


@router.post(
    "/logout",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def logout(
    req: LogoutRequest,
    db: AsyncSession = Depends(get_db_session),
):
    service = AuthService(db)
    await service.logout(req.refresh_token)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
