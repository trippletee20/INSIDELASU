# Billboard advertising: post-launch service

The selected providers are **Paystack and Flutterwave**. The game contains 100 stable billboard slot IDs. Players can tap a billboard face, or approach its supports and choose Interact, to open advertising information and a linked artwork preview. `web/advertise.html` previews an image locally, selects the slot/duration/provider, and explicitly disables booking. It does not upload an image, collect a payment, reserve a slot or publish a campaign.

## Intended player journey

1. Open a billboard, select dates and see an exact NGN quote for its size/location and duration. Identify the advertiser through a separate advertiser account; the anonymous local game profile cannot establish ownership.
2. Upload business artwork and a destination URL through the advertising service. Review the artwork, business details and destination before charging; reject unsuitable submissions with a reason and allow revision.
3. Once approved, create a short inventory hold and a server-generated quote. Choose Paystack or Flutterwave, then open that provider's hosted checkout. The server, never browser code, sets amount, currency and campaign reference.
4. Verify payment server-side. A return URL or a browser “success” message cannot activate an ad. Match verified status, amount, NGN currency, merchant account and the internal reference. Process duplicate/reordered webhook notifications idempotently.
5. Schedule the paid approved campaign in its reserved slot; activate at its start time and expire at its end time using server UTC. Show payment receipts, campaign status and support/refund status in the advertiser portal.
6. The game fetches a read-only feed of approved active campaigns. Load a bounded number of appropriately sized image textures near the player. Show a neutral house ad when offline, expired or unavailable. Clearly label paid placements. Opening the advertiser website requires a deliberate tap; never redirect during walking.

Review before payment reduces the number of people charged for rejected artwork. Inventory holds must expire. If a delayed verified payment arrives after the hold is lost, queue manual resolution/refund rather than overwriting another campaign or accepting a second booking for the same dates.

## Backend required before accepting money

GitHub Pages hosts static files; it cannot safely hold payment secrets, verify webhooks, moderate uploads or publish authoritative shared campaigns. Add an HTTPS API with a persistent database, image storage and an authenticated moderation/advertiser portal. Keep the game available on Pages.

Suggested records: advertisers, slots, creatives, quotes, inventory holds, campaigns, payment attempts, webhook events, refunds and moderation audit events. Campaign lifecycle: `draft → submitted → approved → awaiting_payment → scheduled → live → expired`; include `rejected`, `cancelled` and refund states. A provider payment success only advances an already approved campaign with valid inventory.

Suggested API contract:

| Endpoint | Responsibility |
| --- | --- |
| `GET /v1/ad-slots` | Inventory and published prices, server availability |
| `POST /v1/creatives` | Authenticated, rate-limited image upload and validation |
| `POST /v1/campaigns` | Draft and review submission, advertiser ownership |
| `POST /v1/campaigns/{id}/checkout` | Approved campaign, inventory hold, server quote and provider selection |
| `POST /v1/webhooks/paystack` | Validate provider signature over raw bytes, deduplicate, verify transaction |
| `POST /v1/webhooks/flutterwave` | Validate current provider webhook scheme, deduplicate, verify transaction |
| `GET /v1/campaigns/{id}` | Authenticated owner's booking and payment status |
| `GET /v1/active-campaigns` | Public, cacheable feed containing only approved active artwork |
| `POST /v1/moderation/campaigns/{id}` | Authenticated review decision with audit record |

Implement money in integer kobo internally. Paystack transaction amounts use kobo; Flutterwave's NGN checkout amount needs explicit conversion to naira. Validate against the provider's current official API documentation during integration, and run both providers in test mode before enabling live keys. Store secrets only in the server secret manager. A webhook signature is required, followed by verification of the underlying transaction and its expected campaign, amount and currency.

Uploads need actual image decoding, pixel/file limits, re-encoding and metadata removal; checking a filename or client MIME type is insufficient. Do not accept SVG/HTML as an image. Serve creative images from a dedicated bounded image pipeline. Do not expose advertiser email, phone, payment references or moderation notes in the public feed. Validate destination links and protect advertiser/admin sessions.

Publish clear booking terms: campaign dates, display rotation/share of voice, whether views are guaranteed (recommended initial answer: no), artwork rules, review timing, cancellation/refund policy and contact details. Do not sell a guaranteed impression count without a defined measurement and reporting system.

## Decisions and accounts still needed

- Approved NGN price per billboard tier and duration; exclusive bookings versus rotating ads. Recommended first release: one advertiser per slot per period, charged by duration.
- Merchant business accounts and live approval with Paystack and Flutterwave, settlement details and support/refund owner.
- API/database/storage hosting, advertiser login method and the person reviewing campaigns.
- Published booking terms, privacy information and content rules.

These are production dependencies, not a request to paste secret keys into chat. No live payment integration or server deployment is claimed in this milestone.

## Acceptance before enabling checkout

Exercise both providers' success, cancellation, failure, timeout and delayed payment flows; forged redirects and signatures; mismatched currency/amount/reference; duplicate/reordered webhooks; concurrent slot purchases; hold expiry; refunds; rejected creatives; unauthorized campaign access; image validation; scheduled activation/expiry; offline feed fallback; and texture budgets on Android. Real-money advertising stays separate from the fictional student wallet and local single-player saves.
