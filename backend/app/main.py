from contextlib import asynccontextmanager
import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.cache.factory import init_cache
from app.config import settings
from app.db.session import check_database_at_head
from app.logging_setup import RequestLoggingMiddleware, setup_logging
from app.routes import (
    audio,
    auth,
    catalog,
    discover,
    health,
    history,
    likes,
    me,
    playlists,
    search,
    tracks,
)
from app.services.usage import bandwidth_guard

logger = logging.getLogger("music_app")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Setup structured logging
    setup_logging(level="INFO")

    # 1. Startup validation: APP_JWT_SECRET
    settings.validate_jwt_secret()

    # 2. Database migration head check
    await check_database_at_head()

    # 3. Cache backend initialization & logging
    await init_cache()

    # 4. Start bandwidth usage flusher
    bandwidth_guard.start_background_flusher()

    logger.info(
        f"Application initialized in {settings.APP_ENV} mode. "
        f"Binding host: {settings.HOST}:{settings.PORT}"
    )

    yield

    # Shutdown
    await bandwidth_guard.stop()
    logger.info("Application shutdown complete.")


app = FastAPI(
    title="Melodia Backend Core",
    version="1.0.0",
    lifespan=lifespan,
)

# Request logging & request-ID middleware
app.add_middleware(RequestLoggingMiddleware)

# CORS Middleware
origins = settings.cors_origins_list
if origins or settings.APP_ENV == "development":
    app.add_middleware(
        CORSMiddleware,
        allow_origins=origins if origins else ["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["Authorization", "Content-Type", "Range", "X-Request-ID"],
        expose_headers=[
            "Content-Range",
            "Accept-Ranges",
            "Content-Length",
            "X-Request-ID",
        ],
    )

# Register routes
app.include_router(health.router)
app.include_router(auth.router)
app.include_router(me.router)
app.include_router(history.router)
app.include_router(likes.router)
app.include_router(playlists.router)
app.include_router(search.router)
app.include_router(discover.router)
app.include_router(catalog.router)
app.include_router(tracks.router)
app.include_router(audio.router)
