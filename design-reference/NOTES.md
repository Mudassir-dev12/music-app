# Design Reference Notes

No Figma PNG exports were found in `./design-reference/` during Phase 2 preflight (`ls -la design-reference/` contained only `README.md`).

Per Phase 2 Section 3.3, Section 5 of the Phase 2 specification serves as the authoritative design specification for tokens, typography, spacing, radii, breakpoints, layouts, and player controls:
- **Dark (default):** background `#000000`, surface `#1C1C1E`, surface2 `#2C2C2E`, separator `rgba(84,84,88,0.65)`, text `#FFFFFF`, textSecondary `rgba(235,235,245,0.6)`, textTertiary `rgba(235,235,245,0.3)`, accent `#FA233B`, destructive `#FF453A`
- **Light:** background `#FFFFFF`, surface `#F2F2F7`, surface2 `#E5E5EA`, separator `rgba(60,60,67,0.29)`, text `#000000`, textSecondary `rgba(60,60,67,0.6)`, textTertiary `rgba(60,60,67,0.3)`, accent `#FA2D48`, destructive `#FF3B30`
- **Breakpoints:** phone `< 768`, tablet `768-1023`, desktop `>= 1024`
- **Desktop sidebar width:** `260px`; **Desktop player bar height:** `72-80px`
- **Artwork:** small `44px` (MiniPlayer) / `48px` (TrackRow), hero `min(400px, screenWidth - 64px)`, scale `0.86` paused -> `1.0` playing with spring (`damping: 18, stiffness: 180`).

