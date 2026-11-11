from abc import ABC, abstractmethod
from app.sources.models import ResolvedStream, SearchResponse, Track


class MusicSource(ABC):
    @abstractmethod
    async def search(self, query: str, filter_type: str, limit: int) -> SearchResponse:
        pass

    @abstractmethod
    async def get_track(self, video_id: str) -> Track:
        pass

    @abstractmethod
    async def resolve_stream(self, video_id: str) -> ResolvedStream:
        pass
