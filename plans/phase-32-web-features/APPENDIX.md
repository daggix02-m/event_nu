# Appendix: Minor Findings (Web Parity)

Minor backend gaps surfaced while planning announcements + featured flag
(`BACKEND_CHANGES.md`). These are observations only — **no code changed**.

## 1. `GET /api/v1/me/moments` (missing)

**Finding.** The moments surface is event-scoped only. Shipped routes
(`routes.go`):

```
POST   /api/v1/events/{id}/moments        (protectedIdem)
GET    /api/v1/events/{id}/moments        (public)
DELETE /api/v1/moments/{id}               (protected)
GET    /api/v1/events/{id}/attendees      (public)
```

There is **no "my moments" list** — nothing lets a user (or the web profile
page) fetch their own uploads across all events, newest first.

**Why it matters.** The web profile and the mobile "share moments" entry point
both want a per-user gallery ("Things I've posted"), and the profile may want a
media preview row like the Badges/Recaps surface.

**Design sketch** (for the backend session):

- Route: `GET /api/v1/me/moments` behind `protected()`, paginated.
- Repository: fetch `moments` joined to the owning event where
  `user_id = current_app_user_id()` — the normal own-row pattern.
- **RLS wrinkle (important).** `moments_select_public` only permits reads when
  the parent event is `published`, not `blocked`, not `deleted`:

  ```sql
  CREATE POLICY moments_select_public ON moments FOR SELECT
    USING (is_privileged() OR EXISTS (
      SELECT 1 FROM events e
      WHERE e.id = moments.event_id
        AND e.status = 'published'
        AND e.moderation_status <> 'blocked'
        AND e.deleted_at IS NULL
    ));
  ```

  A user whose moment is attached to a draft/cancelled/blocked event could
  **not** read their own row through that policy. A "my moments" endpoint needs
  an additional owner-read policy, e.g.:

  ```sql
  CREATE POLICY moments_select_own ON moments FOR SELECT
    USING (user_id = current_app_user_id());
  ```

  Add it in the same forward migration as the endpoint, and keep it narrow
  (owner reads only — never the public gallery path).

## 2. Stories vs moments (naming divergence)

**Finding.** Target schema v3 §8.25 defines `stories` + `story_views` + an
`event_gallery_items` dedup table whose FK points at `story_id`; the original
migration index (`00013_stories.sql`) used that naming. The implementation
shipped as **`moments`** (migration `00020_moments.sql`, DB v22):

- Table `moments` with `UNIQUE (user_id, event_id, media_asset_id)` — dedup at
  the source, no separate read-receipt table.
- **No** `story_views` read-receipt/dedup table exists in the shipped schema.
- The Flutter share-moments + gallery feature (Phase 27) and the whole client
  stack already speak "moments".

**Recommendation.**

- Keep `moments` as the name everywhere. Renaming to `stories` provides no
  user value and churns schema, repo, DTO, routes, and the shipped client.
- Correct the *target schema v3 docs* (`event_gallery_items` → moments-equivalent,
  drop the `stories` naming) or add an explicit reconciliation note, so future
  sessions don't invent a duplicate `stories` table.
- Trea `story_views` as **not implemented** (view-in-motion read receipts are
  out of scope); if a "viewed gallery" metric is ever needed, it belongs as a
  counter or `SECURITY DEFINER` aggregate on `moments`, per the schema's own
  §2 opening note on own-row-only tables.

## 3. "Experiences" (undefined)

**Finding.** The Phase 32 brief mentions "experiences" as a web-parity topic.
Searching the entire backend, `docs/EVENT_NU_IMPLEMENTATION_DOCUMENTATION_v3.md`,
and `EVENT_NU_TARGET_SCHEMA_v3.sql` finds **zero** references to "experiences".
It is not a schema, endpoint, DTO, or documented feature anywhere in this repo.

**Recommendation.** Treat "experiences" as an **unresolved product requirement**,
not a backend gap. Before any design:

- Clarify what the web calls "experiences" — likely candidates given the domain:
  a) a UX construct (immersive/organizer "experience" pages);
  b) event add-ons/tiers (which partially overlaps `ticket_types` + Phase 19
     schedule/Q&A);
  c) a marketing term for moments/stories galleries.
- If it turns out to be (a)/(c), fold it into the moments/stories decision above.
- If (b), map it onto the existing `ticket_types`/orders surface before proposing
  any new table.

Until then, no migration for "experiences" should be written.

## 4. Backfill (informational)

The `announcements` / `pages` CMS pair in target schema v3 (§8.26–8.27) was
never migrated. This phase's `BACKEND_CHANGES.md` covers `announcements`
(endpoint parity). `pages` (CMS content pages) is the remaining unspec'd half:
admin-authored `slug`/`content` JSON with a public read (`GET /api/v1/pages/{slug}`)
would be the natural follow-up, but nothing in the product asks for it yet — leave
it documented here rather than spec'd prematurely.