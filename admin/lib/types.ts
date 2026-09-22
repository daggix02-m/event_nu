/** Wire types mirrored from the backend DTOs (internal/api/dto). */

export interface Pagination {
  page: number;
  limit: number;
  total: number;
  has_next: boolean;
}

export interface Page<T> {
  data: T[];
  pagination: Pagination;
}

export interface ApiError {
  error: { code: string; message: string };
}

export interface User {
  id: string;
  email: string;
  username: string;
  bio: string | null;
  photo_url: string | null;
  role: "user" | "admin";
  is_verified: boolean;
  created_at: string;
}

export interface AuthResponse {
  user: User;
  access_token: string;
  refresh_token: string;
  expires_in: number;
}

export interface AdminOrganizerApplication {
  id: string;
  organizer_id: string;
  user_id: string;
  requested_name: string;
  bio: string;
  applicant_username: string | null;
  applicant_email: string | null;
  status: "pending" | "approved" | "rejected" | "needs_more_information" | "withdrawn";
  reviewed_by: string | null;
  reviewed_at: string | null;
  submitted_at: string;
}

export interface AdminEvent {
  id: string;
  organizer_id: string;
  venue_id: string | null;
  category_id: string | null;
  title: string;
  description: string;
  starts_at: string;
  ends_at: string | null;
  price_is_free: boolean;
  price_display: string;
  action_type: string;
  status: "draft" | "published" | "cancelled" | "completed" | "archived";
  moderation_status: "clean" | "reported" | "under_review" | "blocked" | "restored";
  max_attendees: number | null;
  created_at: string;
}

export interface AdminReport {
  id: string;
  reporter_user_id: string;
  entity_type: string;
  entity_id: string;
  reason_code: string;
  description?: string;
  status: string;
  resolution?: string | null;
  resolved_at?: string | null;
  created_at: string;
}