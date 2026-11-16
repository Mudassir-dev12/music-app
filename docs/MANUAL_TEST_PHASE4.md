# Phase 4 Discovery — Manual Test & Verification Guide

This guide walks through manual verification of all Phase 4 Discovery features across the Melodia client and backend.

---

## 1. Prerequisites & Setup

### Start the Local Backend
In terminal 1:
```powershell
cd backend
.venv\Scripts\uvicorn app.main:app --host 127.0.0.1 --port 8610
```

### Configure and Run the Client
Ensure `client/dart_defines.json` contains:
```json
{
  "API_URL": "http://127.0.0.1:8610",
  "APP_NAME": "Melodia",
  "LOCAL_EMAIL": "test@example.com",
  "LOCAL_PASSWORD": "TestPassword123!"
}
```

In terminal 2:
```powershell
cd client
# Run on Windows desktop
flutter run -d windows --dart-define-from-file=dart_defines.json

# OR run in Chrome (if installed)
# flutter run -d chrome --web-port 8611 --dart-define-from-file=dart_defines.json
```

---

## 2. Test Cases

### Test Case 1: Search Auto-Complete & Grouped Results
1. Navigate to **Search** tab.
2. Type `radio` into the search field.
3. Observe:
   - Within ~300ms, query suggestions appear below the search bar.
   - Tapping a suggestion fills the search field and executes the query.
4. Execute a broad search (e.g., `queen` or `coldplay`).
5. Observe:
   - Filter chips appear at the top: `All`, `Songs`, `Albums`, `Artists`, `Playlists`.
   - On `All` (default): A prominent **Top Result** card is displayed with an artwork, title, subtitle, badge, and quick-play button.
   - Grouped sections follow: horizontal carousels for Songs, Albums, Artists, and Playlists.
   - Tapping a filter chip (e.g. `Albums`) switches to a clean vertical list of albums.
6. Clear the search input:
   - Recent searches appear.
   - "Clear" button clears recent search history.

### Test Case 2: Listen Now Feed & Top Picks
1. Navigate to **Listen Now** tab.
2. Observe:
   - A hero **Top Picks** section displays recommended tracks in horizontal carousel cards.
   - Dynamic shelves (e.g. "Mixed for you", "Similar to...", "Recommended music videos") display horizontal carousels of albums, playlists, and artists.
   - Tapping any track in Top Picks immediately starts playback.
   - Tapping an album card navigates to the Album screen (`/album/:id`).
   - Tapping an artist card navigates to the Artist screen (`/artist/:id`).

### Test Case 3: Browse Charts & Mood Categories
1. Navigate to **Browse** tab.
2. Observe:
   - **Charts** section at the top featuring Top Songs and Top Artists carousels.
   - **Moods & Genres** category grid with Apple Music-style rounded colored tiles. Each category has a vibrant title-hashed HSV background color.
3. Tap any Mood category (e.g., `Chill`, `Focus`, or `Workout`).
4. Observe:
   - Navigates to `/mood/:params`.
   - Displays a responsive grid of curated playlists for that mood.
   - Tapping any playlist opens its detail view (`/ytplaylist/:id`).

### Test Case 4: Album Screen Details & Playback
1. From Search, Listen Now, or Browse, tap any Album card.
2. Observe:
   - Large centered cover artwork with rounded corners.
   - Album title, artist name (clickable link back to Artist page), and release year.
   - Prominent **Play** and **Shuffle** pill buttons.
   - Tracklist with track numbers (`1`, `2`, `3`...), title, duration, and track action menus.
   - Bottom metadata footer: total track count, total album duration, and copyright notice.
3. Tap **Play**: The entire album is loaded into the playback queue and track 1 begins playing.
4. Tap **Shuffle**: The album tracks are shuffled and playback begins immediately.

### Test Case 5: Artist Screen Hero & Discography
1. Navigate to an Artist screen (via Search or tapping artist name in an Album/Track).
2. Observe:
   - Large circular hero avatar and bold artist name.
   - Subscriber count / channel stats when available.
   - Top Songs section with Play/Shuffle buttons.
   - Discography sections: Albums carousel, Singles & EPs carousel, and Related Artists carousel.
   - Artist bio / description collapsible section at the bottom.
3. Tap any album in the artist's discography to navigate directly to that album.

### Test Case 6: Synchronized Lyrics & Now Playing
1. Play any popular song with lyrics (e.g., Bohemian Rhapsody or Viva La Vida).
2. Open the **Now Playing** sheet / full screen.
3. On phone:
   - Tap the **Lyrics** quotation button (`Icons.format_quote_rounded`) in the bottom action bar.
   - The synchronized lyrics view overlays the player.
   - As the song plays, the current line is highlighted in bold and auto-scrolls to the center.
   - Tapping on any past or future lyric line immediately seeks playback to that exact timestamp.
4. On desktop / tablet:
   - In the right-hand panel, toggle between **Queue** and **Lyrics** tabs.
   - Lyrics sync smoothly alongside the main player controls.
5. If time-synced lyrics are unavailable for a track:
   - The view gracefully falls back to formatted plain lyrics with scroll support.
   - Lyric provider source/credit is cleanly rendered at the bottom.

### Test Case 7: Autoplay Similar Songs
1. Go to **Settings** (`/settings`).
2. Verify the **PLAYBACK** section has an **Autoplay Similar Songs** toggle switch (default: ON).
3. Play a single track or jump to the very last track in the queue.
4. Let the song finish playing (or seek to 2 seconds before the end).
5. When the song ends:
   - Autoplay triggers automatically via `/watch/{video_id}`.
   - Candidate tracks already in recent history or queue are excluded to avoid duplicates.
   - Next similar song is added to the queue and starts playing seamlessly.
6. Toggle the setting to OFF in Settings, and repeat:
   - Playback stops when the queue completes without adding more songs.

### Test Case 8: Upstream Busy / Rate Limit Handling
1. If YouTube rate-limits or returns 429/503 during high concurrency:
2. The client intercepts `UpstreamBusyError` (`Retry-After`).
3. An Apple Music-style frosted banner slides in at the top showing:
   *"Upstream service is busy. Retrying in Xs..."* with an active countdown timer.
4. User interface remains responsive without crash or blank error screen.
