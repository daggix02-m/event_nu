# Chapa Payment Integration (Phase 15)

How Event Nu talks to Chapa, what we trust and what we don't, and the exact
wire/edge contracts the backend enforces. The signed check-in QR flow is in
`docs/ticket-qr-protocol.md`; order reservation semantics are in the Phase 14
plan.

## Goals

- A buyer creates an order (Phase 14 atomic reservation) and is sent to a Chapa
  checkout (`redirect_url`).
- Chapa posts the outcome to our webhook; we **re-query Chapa** and only act on
  the provider's authoritative answer.
- `paid` → confirm order, issue tickets, notify; `failed` → release inventory;
  `pending/authorized` → wait for a later event.

## Configuration

| Env | Default | Meaning |
|---|---|---|
| `PAYMENT_PROVIDER` | `noop` | `chapa` enables the full flow; anything else uses NoopProvider |
| `CHAPA_SECRET_KEY` | — | Chapa API key (initialize/verify bearer auth); required with `PAYMENT_PROVIDER=chapa` |
| `CHAPA_API_BASE` | `https://api.chapa.co/v1` | API root (override for sandbox/mock) |
| `CHAPA_WEBHOOK_SECRET` | `CHAPA_SECRET_KEY` | verifies webhook HMAC signatures over the raw body |
| `CHAPA_REDIRECT_BASE` | `APIPUBLICBASE` | `return_url` sent to Chapa's checkout |

`noop` is deliberately the default: local dev and tests never accidentally
charge money.

## Provider calls

- **Initialize** — `POST {CHAPA_API_BASE}/transaction/initialize`, bearer
  `CHAPA_SECRET_KEY`. Body: `amount` (major-unit string, e.g. `"100"` for 100.00
  ETB — minor units are converted in `formatMajor`), `currency` (3-letter),
  `email`, `first_name`, `last_name`, `tx_ref` (our order id, globally unique),
  `callback_url` (our webhook), `return_url`, `customization.title =
  "Event Nu order"`. Response `data.checkout_url` is the buyer redirect.
- **Verify** — `GET {CHAPA_API_BASE}/transaction/verify/{tx_ref}` → `data.status`,
  `data.amount`, `data.currency`. Statuses are normalized: `success/completed/
  paid` → success; `failed/cancelled/cancelled_by_user/abandoned/expired` →
  failed; anything else (`pending`, `authorized`, …) → pending.

Both calls time out after 10s.

## Webhook contract

Route: `POST /webhooks/payments/chapa` (registered under the privileged
`service(...)` wrapper, inside `BeginRequestTx`).

- **Signature**: headers `Chapa-Signature` and/or `x-chapa-signature` are
  HMAC-SHA256 hex of the **exact raw request body** signed with
  `CHAPA_WEBHOOK_SECRET` (constant-time comparison). Either header present and
  valid passes; missing signature or a mismatch → **401**; an empty secret never
  validates.
- **Authority**: after the signature check we call `Verify(tx_ref)`; the body's
  own `status` field is never trusted. `tx_ref` is parsed from the body
  (`tx_ref` / `txref` / `trx_ref` aliases). A body with no tx ref → **400**.
- **Outcomes**:
  - success → `ConfirmPaid(order, provider, tx_ref)` (issues tickets) →
    ledger upsert `paid` → best-effort `ticket` notification. Duplicate success
    (`ErrOrderAlreadyPaid`, e.g. provider retries) → idempotent **200 no-op**.
  - failed → `FailPayment` (flips order to `failed`, releases inventory) →
    ledger upsert `failed` with the order's amount/currency. An already-paid
    order receiving a contradictory failure (`ErrOrderAlreadyPaid`) is ignored.
  - pending/authorized → **200** no state change (await a later event).
  - unknown order → **404**; provider-verify/other errors → **500** (Chapa keeps
    redelivering).
- Everything above runs in the request txn; the order+ledger change commits
  atomically with the 200. 4xx/5xx roll back.

## Key design decision: the transaction reference

`tx_ref = order.ID` (UUID) is the **single stable key** everywhere:

- it is what Chapa signs/redelivers (`tx_ref`),
- it is the ledger's `provider_payment_id` (`UNIQUE(provider, provider_payment_id)`),
- it is `orders.provider_ref`,
- `GET /orders/{id}` / `GET /me/orders` surface it as `payment_provider` /
  `provider_ref`.

So the init-time `pending` ledger row and the first webhook event update the
*same* row rather than creating a second one. One payment attempt per order: a
failed order means the buyer places a fresh order (`orders` is locked by
`payment_provider`/`provider_ref` being set).

## Atomicity on init failure

Card-init runs **inside** the order-create request transaction. If the provider
is unreachable the service returns `502 payment_unavailable`, and
`BeginRequestTx` rolls back the request — the pending order and its inventory
reservations vanish together. No orphan order, no leaked inventory; the only
dangling artifact is an uncharged Chapa `tx_ref`. The Chapa HTTP call therefore
runs while the order/reserve txn is open (a single ~100 ms round trip), a
documented tradeoff in exchange for rollback simplicity.

Dev/tests use `PAYMENT_PROVIDER=noop`: `Initiate` returns no `payment` block
and produces no redirect, so the Phase 14 flow is unchanged.

## Payments ledger (migration 00017)

`payments(order_id FK, provider, provider_payment_id, status payment_status
[pending/authorized/paid/failed/refunded/cancelled], amount_minor, currency
char(3), raw_reference jsonb, created/updated/paid_at/failed_at)`. Enforced:

- `UNIQUE(provider, provider_payment_id)` — one ledger row per provider txn.
- `enforce_payment_currency()` trigger — a payment's currency must equal its
  order's currency (never write a cross-currency ledger row).
- RLS: reads = order owner or privileged; writes = privileged only; the
  purchasing user's init-time insert goes through SECURITY DEFINER
  `record_pending_payment` (granted EXECUTE to `app_user`).

## Security notes

- Webhook signature is verified over the raw body before anything is parsed or
  acted on; authority always comes from the provider re-query.
- The orders `provider_ref`/`payment_provider` columns sit on the orders table
  under existing order RLS — no new cross-role read surface.
- No secrets are ever logged: `CHAPA_SECRET_KEY`/`CHAPA_WEBHOOK_SECRET` live
  only in env/config and are never put in DTOs.

## Testing

Unit: `internal/infrastructure/payments/chapa_test.go` (signature math, amount
major/minor conversion, initialize/verify against `httptest`, status
normalization). Integration: `internal/api/handlers/payments_webhook_test.go`
drives the whole pipeline with a scripted `fakeProvider` (checkout init + webhook
success/duplicate, tampered/missing signature, unknown order, failure→inventory
release, init-failure→full rollback), asserting the ledger through a service-role
pool.