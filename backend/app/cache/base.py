from typing import Any, Protocol, runtime_checkable


@runtime_checkable
class Cache(Protocol):
    name: str

    async def get(self, key: str) -> Any | None:
        ...

    async def set(self, key: str, value: Any, ttl: int | None = None) -> None:
        ...

    async def delete(self, key: str) -> None:
        ...

    async def incr(self, key: str, ttl: int) -> int:
        ...
