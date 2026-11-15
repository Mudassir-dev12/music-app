from unittest.mock import AsyncMock, patch
import uuid
import pytest
from httpx import AsyncClient
from sqlalchemy import select
from app.db.models import Track as TrackModel
from app.db.session import get_sessionmaker
from app.sources.models import Artist, SearchResponse, Track


def make_mock_track(video_id: str, title: str = "Upsert Track") -> Track:
    return Track(
        video_id=video_id,
        title=title,
        artists=[Artist(name="Artist A")],
        artist="Artist A",
        album="Album A",
        album_id="alb_a",
        duration_seconds=210,
        thumbnail="https://example.com/a.jpg",
        is_explicit=False,
    )


@pytest.mark.asyncio
async def test_search_and_track_upserts_server_side_only(client: AsyncClient):
    email = f"trackupsert_{uuid.uuid4().hex[:8]}@example.com"
    reg = await client.post(
        "/auth/register", json={"email": email, "password": "ValidPassword123!"}
    )
    token = reg.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    v_search = "srchTrk0001"
    t_search = make_mock_track(v_search, "Search Track")

    # 1. Search endpoint triggers upsert
    with patch(
        "app.routes.search.ytmusic_source.search",
        new=AsyncMock(return_value=SearchResponse(query="test", filter="songs", results=[t_search])),
    ):
        r_srch = await client.get("/search?q=test", headers=headers)
        assert r_srch.status_code == 200
        print("SEARCH JSON:", r_srch.json())

    async with get_sessionmaker()() as db:
        res = await db.execute(select(TrackModel).where(TrackModel.video_id == v_search))
        row = res.scalar_one_or_none()
        assert row is not None
        assert row.title == "Search Track"

    # 2. Track endpoint triggers upsert
    v_track = "metaTrk0001"
    t_track = make_mock_track(v_track, "Meta Track")
    with patch(
        "app.routes.search.ytmusic_source.get_track",
        new=AsyncMock(return_value=t_track),
    ):
        r_trk = await client.get(f"/track/{v_track}", headers=headers)
        assert r_trk.status_code == 200

    async with get_sessionmaker()() as db:
        res2 = await db.execute(select(TrackModel).where(TrackModel.video_id == v_track))
        row2 = res2.scalar_one_or_none()
        assert row2 is not None
        assert row2.title == "Meta Track"
