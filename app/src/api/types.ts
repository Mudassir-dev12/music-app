export interface Artist {
  id: string | null;
  name: string;
}

export interface Track {
  video_id: string;
  title: string;
  artists: Artist[];
  artist: string;
  album: string | null;
  album_id: string | null;
  duration_seconds: number | null;
  thumbnail: string | null;
  is_explicit: boolean;
}

export interface SearchResponse {
  query: string;
  filter: string;
  results: Track[];
}

export interface User {
  id: string;
  email: string;
  display_name: string | null;
  created_at: string;
}

export interface AuthResponse {
  access_token: string;
  refresh_token: string;
  token_type: string;
  expires_in: number;
  user: User;
}

export interface AudioTicketResponse {
  url: string;
  expires_in: number;
}

export interface UsageResponse {
  today_bytes: number;
  daily_limit_bytes: number;
  month_global_bytes: number;
  month_global_limit_bytes: number;
}

