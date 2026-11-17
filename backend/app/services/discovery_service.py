import hashlib
import logging
import re
from typing import List, Optional, Tuple
from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from ytmusicapi import YTMusic
from app.config import settings
from app.services.discovery_normalizer import (
    normalize_album,
    normalize_artist,
    normalize_charts,
    normalize_home_shelves,
    normalize_lyrics,
    normalize_media_item,
    normalize_mood_categories,
    normalize_mood_playlists,
    normalize_playlist,
    normalize_radio_tracks,
)
from app.services.tracks import upsert_tracks
from app.services.upstream import default_upstream_coordinator, run_in_worker
from app.sources.models import (
    AlbumDetail,
    ArtistDetail,
    ChartsResponse,
    HomeResponse,
    Lyrics,
    MediaItem,
    MoodPlaylistsResponse,
    MoodsResponse,
    PlaylistDetail,
    SearchFilterResponse,
    SearchGroupedResponse,
    SearchResponse,
    SearchSuggestionsResponse,
    Shelf,
    Track,
    WatchRadioResponse,
)
from app.sources.ytmusic import normalize_track_dict

logger = logging.getLogger("music_app.discovery_service")


class DiscoveryService:
    def __init__(self, ytm: Optional[YTMusic] = None):
        self._ytm = ytm or YTMusic(
            language=settings.YTMUSIC_LANGUAGE,
            location=settings.YTMUSIC_LOCATION,
        )
        self.coordinator = default_upstream_coordinator

    async def search_songs(
        self,
        db: AsyncSession,
        query: str,
        limit: int = 20,
    ) -> Tuple[SearchResponse, str]:
        cache_key = f"discovery:search:songs:{hashlib.sha1(f'{query}|{limit}'.encode()).hexdigest()}"

        async def fetch():
            raw = await run_in_worker(self._ytm.search, query=query, filter="songs", limit=limit)
            tracks = []
            for item in raw:
                trk = normalize_track_dict(item)
                if trk:
                    tracks.append(trk.model_dump())
            return {"query": query, "filter": "songs", "results": tracks}

        data, cache_status = await self.coordinator.execute(cache_key, settings.SEARCH_TTL, fetch)
        response = SearchResponse(**data)
        if response.results:
            await upsert_tracks(db, response.results)
        return response, cache_status

    async def search_filter(
        self,
        db: AsyncSession,
        query: str,
        filter_type: str,
        limit: int = 20,
    ) -> Tuple[SearchFilterResponse, str]:
        cache_key = f"discovery:search:{filter_type}:{hashlib.sha1(f'{query}|{limit}'.encode()).hexdigest()}"

        async def fetch():
            raw = await run_in_worker(self._ytm.search, query=query, filter=filter_type, limit=limit)
            items = []
            single_type = filter_type.rstrip("s")  # albums -> album, artists -> artist, playlists -> playlist
            for r in raw:
                item = normalize_media_item(r, default_type=single_type)
                if item:
                    items.append(item.model_dump())
            return {"query": query, "filter": filter_type, "results": items}

        data, cache_status = await self.coordinator.execute(cache_key, settings.SEARCH_TTL, fetch)
        response = SearchFilterResponse(**data)
        tracks_to_upsert = [it.track for it in response.results if it.track is not None]
        if tracks_to_upsert:
            await upsert_tracks(db, tracks_to_upsert)
        return response, cache_status

    async def search_grouped(
        self,
        db: AsyncSession,
        query: str,
    ) -> Tuple[SearchGroupedResponse, str]:
        cache_key = f"discovery:search:grouped:{hashlib.sha1(query.encode()).hexdigest()}"

        async def fetch():
            raw = await run_in_worker(self._ytm.search, query=query, limit=25)
            top_result = None
            songs: List[MediaItem] = []
            albums: List[MediaItem] = []
            artists: List[MediaItem] = []
            playlists: List[MediaItem] = []

            for idx, r in enumerate(raw):
                item = normalize_media_item(r)
                if not item:
                    continue

                if idx == 0 or r.get("category") == "Top result":
                    if top_result is None:
                        top_result = item

                if item.type == "song" and len(songs) < 5:
                    songs.append(item)
                elif item.type == "album" and len(albums) < 4:
                    albums.append(item)
                elif item.type == "artist" and len(artists) < 4:
                    artists.append(item)
                elif item.type == "playlist" and len(playlists) < 4:
                    playlists.append(item)

            sections: List[Shelf] = []
            if songs:
                sections.append(Shelf(key="songs", title="Songs", items=songs))
            if albums:
                sections.append(Shelf(key="albums", title="Albums", items=albums))
            if artists:
                sections.append(Shelf(key="artists", title="Artists", items=artists))
            if playlists:
                sections.append(Shelf(key="playlists", title="Playlists", items=playlists))

            return {
                "query": query,
                "top_result": top_result.model_dump() if top_result else None,
                "sections": [s.model_dump() for s in sections],
            }

        data, cache_status = await self.coordinator.execute(cache_key, settings.SEARCH_TTL, fetch)
        response = SearchGroupedResponse(**data)
        tracks_to_upsert: List[Track] = []
        if response.top_result and response.top_result.track:
            tracks_to_upsert.append(response.top_result.track)
        for s in response.sections:
            for it in s.items:
                if it.track:
                    tracks_to_upsert.append(it.track)
        if tracks_to_upsert:
            await upsert_tracks(db, tracks_to_upsert)
        return response, cache_status

    async def get_suggestions(self, query: str) -> Tuple[SearchSuggestionsResponse, str]:
        cache_key = f"discovery:suggest:{hashlib.sha1(query.encode()).hexdigest()}"

        async def fetch():
            try:
                raw = await run_in_worker(self._ytm.get_search_suggestions, query=query)
                suggestions = [str(s) for s in raw if isinstance(s, (str, int))][:8]
                return {"suggestions": suggestions}
            except Exception as e:
                logger.warning(f"Suggestions upstream failed for query '{query}': {e}. Returning empty.")
                return {"suggestions": []}

        try:
            data, cache_status = await self.coordinator.execute(cache_key, settings.TTL_SUGGEST, fetch)
            return SearchSuggestionsResponse(**data), cache_status
        except Exception:
            return SearchSuggestionsResponse(suggestions=[]), "miss"

    async def get_home(self, db: AsyncSession) -> Tuple[HomeResponse, str]:
        cache_key = "discovery:home"

        async def fetch():
            shelves = []
            try:
                raw = await run_in_worker(self._ytm.get_home, limit=8)
                shelves = normalize_home_shelves(raw)
            except Exception as e:
                logger.warning(f"get_home failed: {e}")

            # If get_home returned no shelves (common when unauthenticated), fallback to charts
            if not shelves:
                try:
                    raw_charts = await run_in_worker(self._ytm.get_charts, country=settings.YTMUSIC_LOCATION)
                    shelves = normalize_charts(raw_charts)
                except Exception as e:
                    logger.warning(f"Fallback charts failed: {e}")

            return {"shelves": [s.model_dump() for s in shelves]}

        data, cache_status = await self.coordinator.execute(cache_key, settings.TTL_HOME, fetch)
        response = HomeResponse(**data)
        tracks_to_upsert: List[Track] = []
        for s in response.shelves:
            for it in s.items:
                if it.track:
                    tracks_to_upsert.append(it.track)
        if tracks_to_upsert:
            await upsert_tracks(db, tracks_to_upsert)
        return response, cache_status

    async def get_charts(self, db: AsyncSession, region: str) -> Tuple[ChartsResponse, str]:
        cache_key = f"discovery:charts:{region}"

        async def fetch():
            raw = await run_in_worker(self._ytm.get_charts, country=region)
            shelves = normalize_charts(raw)
            return {"shelves": [s.model_dump() for s in shelves]}

        data, cache_status = await self.coordinator.execute(cache_key, settings.TTL_CHARTS, fetch)
        response = ChartsResponse(**data)
        tracks_to_upsert: List[Track] = []
        for s in response.shelves:
            for it in s.items:
                if it.track:
                    tracks_to_upsert.append(it.track)
        if tracks_to_upsert:
            await upsert_tracks(db, tracks_to_upsert)
        return response, cache_status

    async def get_moods(self) -> Tuple[MoodsResponse, str]:
        cache_key = "discovery:moods"

        async def fetch():
            raw = await run_in_worker(self._ytm.get_mood_categories)
            sections = normalize_mood_categories(raw)
            return {"sections": [sec.model_dump() for sec in sections]}

        data, cache_status = await self.coordinator.execute(cache_key, settings.TTL_MOODS, fetch)
        return MoodsResponse(**data), cache_status

    async def get_mood_playlists(self, db: AsyncSession, params: str) -> Tuple[MoodPlaylistsResponse, str]:
        cache_key = f"discovery:mood_playlists:{params}"

        async def fetch():
            raw = await run_in_worker(self._ytm.get_mood_playlists, params=params)
            items = normalize_mood_playlists("Playlists", raw)
            return {"title": "Playlists", "items": [it.model_dump() for it in items]}

        data, cache_status = await self.coordinator.execute(cache_key, settings.TTL_PLAYLIST, fetch)
        response = MoodPlaylistsResponse(**data)
        return response, cache_status

    async def get_album(self, db: AsyncSession, browse_id: str) -> Tuple[AlbumDetail, str]:
        cache_key = f"discovery:album:{browse_id}"

        async def fetch():
            raw = await run_in_worker(self._ytm.get_album, browseId=browse_id)
            album = normalize_album(raw, album_id=browse_id)
            if not album:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Album not found.")
            return album.model_dump()

        data, cache_status = await self.coordinator.execute(cache_key, settings.TTL_ALBUM, fetch)
        album = AlbumDetail(**data)
        if album.tracks:
            await upsert_tracks(db, album.tracks)
        return album, cache_status

    async def get_artist(self, db: AsyncSession, channel_id: str) -> Tuple[ArtistDetail, str]:
        cache_key = f"discovery:artist:{channel_id}"

        async def fetch():
            raw = await run_in_worker(self._ytm.get_artist, channelId=channel_id)
            artist = normalize_artist(raw)
            if not artist:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Artist not found.")
            return artist.model_dump()

        data, cache_status = await self.coordinator.execute(cache_key, settings.TTL_ARTIST, fetch)
        artist = ArtistDetail(**data)
        if artist.top_songs:
            await upsert_tracks(db, artist.top_songs)
        return artist, cache_status

    async def get_playlist(self, db: AsyncSession, playlist_id: str, limit: int = 100) -> Tuple[PlaylistDetail, str]:
        cache_key = f"discovery:ytplaylist:{playlist_id}:{limit}"

        async def fetch():
            # ytmusicapi requires playlistId without 'VL' prefix
            clean_id = playlist_id[2:] if playlist_id.startswith("VL") else playlist_id
            raw = await run_in_worker(self._ytm.get_playlist, playlistId=clean_id, limit=limit)
            pl = normalize_playlist(raw)
            if not pl:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Playlist not found.")
            return pl.model_dump()

        data, cache_status = await self.coordinator.execute(cache_key, settings.TTL_PLAYLIST, fetch)
        playlist = PlaylistDetail(**data)
        if playlist.tracks:
            await upsert_tracks(db, playlist.tracks)
        return playlist, cache_status

    async def get_radio(self, db: AsyncSession, video_id: str, limit: int = 25) -> Tuple[WatchRadioResponse, str]:
        cache_key = f"discovery:radio:{video_id}:{limit}"

        async def fetch():
            raw = await run_in_worker(self._ytm.get_watch_playlist, videoId=video_id, limit=limit + 5, radio=True)
            tracks = normalize_radio_tracks(raw, current_video_id=video_id)[:limit]
            return {"tracks": [t.model_dump() for t in tracks]}

        data, cache_status = await self.coordinator.execute(cache_key, settings.TTL_RADIO, fetch)
        response = WatchRadioResponse(**data)
        if response.tracks:
            await upsert_tracks(db, response.tracks)
        return response, cache_status

    async def get_lyrics(self, video_id: str) -> Tuple[Lyrics, str]:
        cache_key = f"discovery:lyrics:{video_id}"

        async def fetch():
            # 1. Fetch watch playlist to get lyrics browseId
            watch = await run_in_worker(self._ytm.get_watch_playlist, videoId=video_id, limit=1)
            lyrics_id = watch.get("lyrics") if isinstance(watch, dict) else None
            if not lyrics_id:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Lyrics aren't available for this song.")

            # 2. Fetch lyrics using lyrics_id with timestamps
            try:
                raw_lyrics = await run_in_worker(self._ytm.get_lyrics, browseId=lyrics_id, timestamps=True)
            except Exception as e:
                logger.warning(f"Upstream get_lyrics failed for {lyrics_id}: {e}")
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Lyrics aren't available for this song.")

            lyrics_model = normalize_lyrics(video_id, raw_lyrics)
            if not lyrics_model.lines:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Lyrics aren't available for this song.")
            return lyrics_model.model_dump()

        data, cache_status = await self.coordinator.execute(cache_key, settings.TTL_LYRICS, fetch)
        return Lyrics(**data), cache_status


default_discovery_service = DiscoveryService()
