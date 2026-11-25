# ViewRec mobile API (v1): what the app calls

For the backend developer. This file lists **every request the ViewRec mobile app makes**, with the exact request and response it expects. The app's code is already written against it (`lib/repo.dart`, `lib/web_data.dart`), so if the API matches this file the app needs no changes. If something here cannot be built as written, tell us and we change the app instead.

It replaces the older `API_CONTRACT.md`. Names, paths and shapes here are the final ones.

**Marks used below**
- ✅ **Reuse**: the website already does this; the endpoint should call the same code (`src/server/repos/*`, the same plan, role and send-gate checks as the website).
- 🔁 **Wrap**: a public route already exists (`/api/review/*`); expose it under `/api/v1/public/...`.
- 🆕 **New**: needs new tables or a new service (the database additions are in section 5).

---

## 1. Conventions

**Address and format**
- Base: `https://<host>/api/v1`. HTTPS only. JSON (UTF-8). Files go as `multipart/form-data`.
- Every path in this file is relative to that base, for example `GET /overview` means `GET /api/v1/overview`.

**Headers the app always sends**

| Header | Value |
| --- | --- |
| `Authorization` | `Bearer <access token>` (not sent to the public `/public/...` routes and `/meta`, `/auth/login`) |
| `X-App-Version` | `1.0.0` (the app version) |
| `X-App-Platform` | `android` or `ios` |
| `X-Workspace-Id` | optional: act inside another business the person is a member of (see Workspaces) |
| `Content-Type` | `application/json` on JSON requests |

**Success:** `200` with the body shown, `201` for something created (returns the created object), `204` for no body.

**Errors:** any status `>= 400` with a body like

```json
{ "error": "Human readable message the app shows to the person", "code": "plan_required" }
```

| Status | When | `code` examples |
| --- | --- | --- |
| 400 | bad input | `bad_request` |
| 401 | no or expired token | `unauthorized` (the app then calls `/auth/refresh`) |
| 403 | allowed in general but not now | `plan_required` (adds `"needs": "pro"`), `trial_ended`, `verification_required`, `forbidden` |
| 404 | unknown id, or a token that is invalid or expired | `not_found` |
| 409 | conflict, for example already followed | `conflict` |
| 413 | file too big | `too_large` |
| 422 | validation | `invalid` (optionally `"fields": { "email": "Not a valid address" }`) |
| 429 | too many requests | `rate_limited` (`Retry-After` header) |

The app shows `error` as written, so keep it short and plain. `plan_required` and `trial_ended` make the app show its upgrade explanation.

**Ids** are strings. **Times:** every object has a display string `when` (for example `"12 min ago"`, in the business time zone) because that is what the screens show today. Please also send an ISO 8601 UTC `at` next to it (`"at": "2026-11-25T14:03:11Z"`) so the app can format times itself later. The app ignores `at` for now.

**Lists** are plain JSON arrays. Lists that can grow (feed, messages, comments, customers, testimonials, leads) accept `?limit=` (default 30, max 100) and `?cursor=`, and return the next cursor in the response header `X-Next-Cursor` (absent on the last page). Messages and comments are returned oldest first; the feed and stories newest first.

**Uploads limits** (reject with 413): photo 15 MB; video 100 MB and 3 minutes; voice note 10 MB and 5 minutes; file 25 MB; gallery file 100 MB, 2 GB per business; customer testimonial video 100 MB. Check the real type by content, not by file name.

**Plan rules:** the server enforces them (the app only explains). Features and the minimum plan: contact bundles, embeds, subtitles, social posting, avatar mode, reminder schedule = Pro; removing the watermark = Pro Plus. An account whose trial or plan is not active gets `403 trial_ended` on every change (reading is still allowed).

**Safety rules for anything that messages customers** (invitations, reminders, group and marketing email, SMS): go through the website's **send gate** (opt-outs, 180-day frequency cap, reminder cap, quiet hours 08:00 to 20:00 in the customer's time zone). The phone never sends directly.

---

## 2. Endpoint index

Marks: ✅ reuse, 🔁 wrap an existing public route, 🆕 new. "Screen" is where the app uses it.

### Start, sign-in, devices
| # | Method | Path | Mark | Screen |
| --- | --- | --- | --- | --- |
| 1 | GET | `/meta` (public) | 🆕 | app start: minimum version, feature flags |
| 2 | POST | `/auth/login` (public) | 🆕 | Sign in |
| 3 | POST | `/auth/2fa` (public) | 🆕 | Sign in, 6-digit code |
| 4 | POST | `/auth/refresh` (public) | 🆕 | silent, on 401 |
| 5 | POST | `/auth/logout` | 🆕 | Settings |
| 6 | POST | `/auth/password/forgot` (public) | ✅ | Sign in |
| 7 | POST | `/auth/password/reset` (public) | ✅ | Sign in |
| 8 | POST | `/devices` | 🆕 | push token, after sign-in |
| 9 | DELETE | `/devices/:token` | 🆕 | sign out |

### Dashboard and business
| # | Method | Path | Mark | Screen |
| --- | --- | --- | --- | --- |
| 10 | GET | `/overview` | ✅ | Home |
| 11 | GET | `/insights` | ✅ | Insights |
| 12 | GET | `/notifications` | ✅ | Notifications |
| 13 | POST | `/notifications/read` | ✅ | Notifications |
| 14 | GET | `/billing` | ✅ | Plan and billing, Home strip, locks |
| 15 | GET | `/billing/checkout-link` | ✅ | Plan and billing (opens the website payment page) |
| 16 | GET | `/profile` | ✅ | Settings |
| 17 | PUT | `/profile` | ✅ | Settings |
| 18 | GET | `/automations` | ✅ | Automations |
| 19 | PUT | `/automations` | ✅ | Automations |
| 20 | GET | `/accounts` | ✅ | Connected accounts |
| 21 | PUT | `/accounts/:platformId` | ✅ | Connect |
| 22 | DELETE | `/accounts/:platformId` | ✅ | Disconnect |
| 23 | GET | `/posts` | ✅ | Publishing |

### Customers, invitations, testimonials, leads
| # | Method | Path | Mark | Screen |
| --- | --- | --- | --- | --- |
| 24 | GET | `/customers` | ✅ | Phonebook |
| 25 | POST | `/customers` | ✅ | Add contact |
| 26 | PATCH | `/customers/:id` | ✅ | Approve, skip |
| 27 | POST | `/customers/import` | ✅ | Import list |
| 28 | POST | `/invitations` | ✅ | Invite (send) |
| 29 | POST | `/customers/:id/remind` | ✅ | Send reminder |
| 30 | GET | `/videos` | ✅ | Testimonials |
| 31 | PATCH | `/videos/:id` | ✅ | Approve, publish |
| 32 | GET | `/leads` | ✅ | Leads, Inbox |
| 33 | PATCH | `/leads/:id` | ✅ | status |
| 34 | GET | `/leads/:id/messages` | 🆕 | Conversation |
| 35 | POST | `/leads/:id/messages` | 🆕 | send text |
| 36 | POST | `/leads/:id/messages/attachment` | 🆕 | photo, file, voice note |
| 37 | PATCH | `/leads/:id/messages/:messageId` | 🆕 | edit |
| 38 | DELETE | `/leads/:id/messages/:messageId` | 🆕 | delete |
| 39 | POST | `/leads/:id/calls` | 🆕 | note "You called" |

### Media tab (feed, stories, create, social)
| # | Method | Path | Mark | Screen |
| --- | --- | --- | --- | --- |
| 40 | GET | `/feed` | 🆕 | Media |
| 41 | GET | `/stories` | 🆕 | Home, Media |
| 42 | POST | `/stories/:groupId/seen` | 🆕 | story viewer |
| 43 | POST | `/posts` (multipart) | 🆕 | Create: post, reel, story |
| 44 | DELETE | `/posts/:id` | 🆕 | your own post |
| 45 | PUT / DELETE | `/posts/:id/like` | 🆕 | like |
| 46 | PUT / DELETE | `/posts/:id/save` | 🆕 | save |
| 47 | GET | `/posts/:id/comments` | 🆕 | comments |
| 48 | POST | `/posts/:id/comments` | 🆕 | add comment |
| 49 | DELETE | `/comments/:id` | 🆕 | delete comment |
| 50 | PUT / DELETE | `/accounts/:businessId/follow` | 🆕 | follow |
| 51 | GET | `/profiles/:handle` | 🆕 | business public profile |
| 52 | GET | `/profiles/:handle/followers` | 🆕 | follower list |
| 53 | POST | `/reports` | 🆕 | report (App Store requirement) |
| 54 | PUT / DELETE | `/blocks/:businessId` | 🆕 | block (App Store requirement) |

### Website tools now in the app
| # | Method | Path | Mark | Screen |
| --- | --- | --- | --- | --- |
| 55 | GET | `/gallery/folders` | ✅ | Gallery |
| 56 | POST | `/gallery/folders` | ✅ | Gallery |
| 57 | GET | `/gallery/items` | ✅ | Gallery |
| 58 | POST | `/gallery/upload` (multipart) | ✅ | Gallery |
| 59 | PATCH | `/gallery/items/:id` | ✅ | move to folder |
| 60 | DELETE | `/gallery/items/:id` | ✅ | Gallery |
| 61 | GET | `/bundles` | ✅ | Contact bundles |
| 62 | POST | `/bundles` | ✅ | create |
| 63 | PUT | `/bundles/:id` | ✅ | edit |
| 64 | DELETE | `/bundles/:id` | ✅ | delete |
| 65 | POST | `/bundles/:id/send` | ✅ | email the group |
| 66 | GET | `/calendar?month=YYYY-MM` | ✅ | Calendar |
| 67 | GET | `/templates` | ✅ | Review templates |
| 68 | POST | `/templates` | ✅ | create |
| 69 | PUT | `/templates/:id` | ✅ | edit |
| 70 | DELETE | `/templates/:id` | ✅ | delete |
| 71 | PUT | `/templates/:id/default` | ✅ | make default |
| 72 | GET | `/verification` | ✅ | Verification |
| 73 | POST | `/verification/documents` (multipart) | ✅ | upload document |
| 74 | GET | `/review-requests` | ✅ | Review requests |
| 75 | POST | `/review-requests/:id/approve` | ✅ | approve |
| 76 | POST | `/review-requests/:id/decline` | ✅ | decline |
| 77 | GET | `/referrals` | ✅ | Referral hub |
| 78 | GET | `/video-settings` | ✅ | Subtitles and watermark |
| 79 | PUT | `/video-settings` | ✅ | save |
| 80 | GET | `/embeds` | ✅ | Embeds |
| 81 | POST | `/embeds` | ✅ | create |
| 82 | DELETE | `/embeds/:id` | ✅ | delete |
| 83 | GET | `/support/thread` | ✅ | Support (website support chat) |
| 84 | POST | `/support/thread` | ✅ | send text |
| 85 | POST | `/support/thread/attachment` | 🆕 | photo, file, voice note |
| 86 | PATCH | `/support/thread/messages/:id` | 🆕 | edit |
| 87 | DELETE | `/support/thread/messages/:id` | 🆕 | delete |
| 88 | GET | `/security` | ✅ | Security |
| 89 | PUT | `/security/two-factor` | ✅ | Security |
| 90 | DELETE | `/security/devices/:id` | ✅ | sign out one device |
| 91 | POST | `/security/sign-out-others` | ✅ | sign out other devices |
| 92 | GET | `/workspaces` | ✅ | Workspaces |
| 93 | POST | `/workspaces/:id/switch` | ✅ | switch |
| 94 | POST | `/marketing/email` | ✅ | Marketing email |

### Customer side (no sign-in; the invitation token is the credential)
| # | Method | Path | Mark | Screen |
| --- | --- | --- | --- | --- |
| 95 | GET | `/public/invites/:token` | 🔁 | recording flow, first screen |
| 96 | POST | `/public/invites/:token/video` | 🔁 | upload video (wraps `/api/review/submit-video`) |
| 97 | POST | `/public/invites/:token/written` | 🔁 | written review (wraps `/api/review/submit`) |

**97 endpoints** (some rows cover a PUT and a DELETE on one path).

**Not called by the app yet.** The app already has the screens for these, but they still run on sample data until each is connected, so expect the first calls to them in the app's later releases: 1 to 9 (start and sign-in screens exist, wiring comes with the first connection phase), 13, 15, 27, 28, 29, 44, 49, 51 to 54, 95. All other endpoints are already called by the app's code (`ApiRepo` and `ApiWebRepo`) when it is built with `API_URL`.

---

## 3. Details

### 3.1 Start and sign-in

**1. GET /meta** (public). The app calls it on start.
```json
{ "minAppVersion": "1.0.0", "latestAppVersion": "1.0.3",
  "features": { "media": true, "inbox": true, "supportChat": true, "inAppCalls": false } }
```
If the app version is below `minAppVersion` the app shows an "Update the app" screen. `features` hides a whole tab or tool until it is ready (feature flags).

**2. POST /auth/login** (public). Email and password, as the website's sign-in.
```json
// request
{ "email": "demo@viewrec.com", "password": "..." }
// 200: signed in
{ "accessToken": "...", "refreshToken": "...", "expiresIn": 900, "user": { "id": "u1", "name": "Hartley Roofing", "email": "demo@viewrec.com", "role": "account" } }
// 200: a second step is needed
{ "twoFactorRequired": true, "challengeId": "c_8f2a" }
```
Access token short-lived (15 minutes). Refresh token long-lived (30 days), stored hashed in the existing `sessions` table with one new nullable column `client = 'mobile'`, so the website's security panel lists the phone and can sign it out. Wrong password: `401 {"error":"Email or password is not right"}`.

**3. POST /auth/2fa** (public): `{ "challengeId": "c_8f2a", "code": "123456" }` returns the same body as a successful login.

**4. POST /auth/refresh** (public): `{ "refreshToken": "..." }` returns `{ "accessToken", "refreshToken", "expiresIn" }` (rotate the refresh token). Invalid: `401`.

**5. POST /auth/logout**: ends this session. `204`.

**6 and 7. Password reset** (same flow as the website: a code by email). `POST /auth/password/forgot {"email"}` then `POST /auth/password/reset {"email","code","password"}`. Always answer `204` to `forgot` (do not reveal whether the address exists).

**8. POST /devices**: `{ "platform": "android", "token": "<FCM token>", "appVersion": "1.0.0" }`, `204`. **9. DELETE /devices/:token**: `204`. Used for push notifications.

---

### 3.2 Dashboard and business

**10. GET /overview**
```json
{ "testimonials": 7, "videos": 7, "waiting": 1, "averageRating": 5.0,
  "customers": 2, "invitesSent": 31, "reviewPages": 1, "linkedAccounts": 4, "embeds": 0,
  "videoLink": "https://viewrec.com/r/demo" }
```

**11. GET /insights**
```json
{ "weeklyViews": [120, 180, 150, 260, 310, 280, 420, 512], "totalViews": 2232, "plays": 1604,
  "linkClicks": 389, "avgWatchPercent": 72, "responseRate": 0.28,
  "byPlatform": [{ "platform": "Google", "views": 940 }, { "platform": "Facebook", "views": 610 }] }
```
`weeklyViews` = last 8 weeks, oldest first. `responseRate` 0 to 1.

**12. GET /notifications** → `[{ "id": "n1", "kind": "video", "title": "Lena Fischer recorded a video", "subtitle": "Ready for your approval · 2h ago" }]`. `kind`: `video | suggestion | views | invite | lead`. **13. POST /notifications/read** `{ "ids": ["n1"] }` (or `{ "all": true }`), `204`.

**14. GET /billing**
```json
{ "plan": "Pro", "status": "trial", "trialDay": 4, "trialLength": 15,
  "afterTrialNote": "then $49 / month on Standard unless you choose another plan.",
  "billingEmail": "demo@viewrec.com", "hasCard": false,
  "usage": [{ "label": "Social posts", "used": 9, "limit": "22" }],
  "invoices": [{ "title": "Trial activation", "amount": "$1.00", "date": "19 Nov 2026" }] }
```
`status`: `trial | active | past_due | cancelled`. `plan`: `Standard | Pro | Pro Plus | Managed`. During a trial the account has Pro features. `limit` is a string (a number or text such as `"unlimited"`). The app uses `plan` and `status` to explain locked features and to show the trial strip on Home.

**15. GET /billing/checkout-link** → `{ "url": "https://viewrec.com/billing/..." }`. Apple and Google require their own billing for subscriptions bought inside an app, so for now the app **opens this link in the browser** and does not take payment itself. (Open question for the boss, see section 7.)

**16 and 17. Business profile** (`GET`/`PUT /profile`)
```json
{ "name": "Hartley Roofing", "category": "Home & Trades", "phone": "+44 161 496 0123",
  "email": "demo@viewrec.com", "website": "https://hartleyroofing.example",
  "area": "Greater Manchester · 25 miles", "about": "Family-run roofers for over 20 years." }
```
Validate `name` not empty and `email` valid.

**18 and 19. Automations** (`GET`/`PUT /automations`, PUT replaces)
```json
{ "requestAfterJob": true, "autoInvite": true, "thankYou": true, "reminders": true,
  "autoPublish": false, "politeHours": true, "reminderCount": 2, "gapDays": 3, "channel": "sms_email" }
```
`channel`: `sms_email | sms | email | whatsapp`. `reminderCount` 1 to 5, `gapDays` 1 to 10. A plan that does not allow a setting: `403 plan_required`.

**20. GET /accounts** → connected platforms only: `{ "google": "Hartley Roofing · Manchester", "fb": "Hartley Roofing Ltd" }`. Platform ids: `google, web, fb, ig, yt, tt, li, pin`.
**21. PUT /accounts/:platformId** starts connecting. For a platform that needs a login (Facebook) answer `{ "redirectUrl": "https://..." }` and the app opens it in the browser; otherwise `200`. **22. DELETE /accounts/:platformId** disconnects, `200`.

**23. GET /posts**
```json
{ "usedThisMonth": 9, "monthlyLimit": 22,
  "posts": [{ "id": "p1", "title": "Priya Nair - quote card", "platform": "Instagram",
              "when": "Today, 17:30", "status": "scheduled", "reactions": 0 }] }
```
`status`: `scheduled | published | failed`. `platform` is the first word of the platform name.

---

### 3.3 Customers, invitations, testimonials, leads

**24. GET /customers**
```json
[{ "id": "1", "name": "Sarah Mitchell", "job": "Roof replacement", "date": "12 days ago",
   "reason": "Recent job, replied to your last email", "status": "suggested", "phone": "+44 7700 900123" }]
```
`status`: `suggested | approved | invited | recorded | skipped`. `phone` may be empty (needed for the call button).

**25. POST /customers** `{ "name": "Jane Smith", "job": "Roof repair", "contact": "+44 7700 900123" }` → `201` the new customer (status `approved`). `contact` is a phone or an email.
**26. PATCH /customers/:id** `{ "status": "approved" }` and/or `{ "name", "job", "contact" }` (the app's swipe-right edit). A `skipped` customer must never be invited.

**26b. DELETE /customers/:id** removes the contact (the app's swipe-left remove, always confirmed by the user first). Returns `204`. Their invitations and videos must stay.

**27. POST /customers/import** (multipart): `file` (.csv or .xlsx) and `mapping` as a JSON string, field to column header, for example `{"Name":"Customer name","Mobile":"Mobile","Email":"Email address","Job done":"Service","Date":"Completed on"}`. `Name` is required and at least one of `Mobile` or `Email`.
```json
{ "rows": 212, "reachable": 143, "excluded": 69, "estimateLow": 12, "estimateHigh": 22 }
```
Opted-out people and duplicates are excluded and counted in `excluded`.

**28. POST /invitations** sends invitations through the send gate (email, SMS).
```json
// request
{ "customerIds": ["1", "2"], "channel": "sms_email", "message": "Optional custom text" }
// 200
{ "sent": 1, "queued": 0, "skipped": [{ "customerId": "2", "reason": "opted_out" }] }
```
`reason`: `opted_out | recently_contacted | no_contact_details | quiet_hours_waiting | plan_limit`. Without an active trial or plan: `403 trial_ended`.
**29. POST /customers/:id/remind** sends the next reminder (same gate), same response shape.

**30. GET /videos** (testimonials)
```json
[{ "id": "v1", "name": "Lena Fischer", "job": "Skylight install", "duration": "1:48",
   "quote": "They turned up when they said they would...", "status": "pending", "views": 0,
   "hue": "#3b2a6b", "platforms": ["Google", "Website"], "rating": 5, "written": false,
   "url": "https://cdn.example.com/v1.mp4", "thumbnailUrl": "https://cdn.example.com/v1.jpg" }]
```
`status`: `pending | approved | published`. `written: true` is a text testimonial (no video). `hue` is a fallback thumbnail colour.
**31. PATCH /videos/:id** `{ "status": "published", "platforms": ["Google", "Facebook"] }` (either field optional). Publishing happens only when the person explicitly publishes; `status: "published"` with `platforms` starts that. Approving needs an active plan (`403 trial_ended`).

**32. GET /leads**
```json
[{ "id": "l1", "name": "Rebecca Shaw", "service": "Roof inspection",
   "message": "Hi, I saw your video reviews...", "when": "12 min ago", "source": "Directory",
   "status": "new", "phone": "+44 7700 800211", "lastNote": "You: Voice note 0:12" }]
```
`status`: `new | contacted | won | lost`. `source`: `Directory | Review page | Website embed`. `lastNote` (optional) is the latest message preview when it is not the first one, for the Inbox list. **33. PATCH /leads/:id** `{ "status": "contacted" }`.

**34 to 39. Lead conversation (the Inbox).** 🆕 One conversation per lead.

The message object (also used by Support):
```json
{ "id": "m1", "from": "business", "text": "Thanks - when suits you?", "when": "just now", "at": "2026-11-25T14:03:11Z",
  "kind": "text", "fileName": "", "url": "", "size": 0, "durationMs": 0,
  "status": "read", "edited": false }
```
- `from`: `customer` (the other person) or `business` (you).
- `kind`: `text | image | file | voice | call`. For `image`, `file`, `voice`: `fileName`, `url` (a playable or downloadable link), `size` (bytes), and for voice `durationMs`. For `call`, `text` is `"You called"`.
- `status` is for messages you sent: `sent | delivered | read`. **The server sets `delivered` and `read`** (when the other side's device receives and opens it). The app shows one tick, two ticks and two blue ticks, and polls the list every 2 seconds while a conversation is open.
- `edited`: true once the text was changed.

| Call | Request | Response |
| --- | --- | --- |
| `GET /leads/:id/messages` | `?limit=&cursor=` | array of messages, oldest first |
| `POST /leads/:id/messages` | `{ "text": "..." }` | `201` the message. The first reply moves a `new` lead to `contacted` |
| `POST /leads/:id/messages/attachment` | multipart: `file`, `kind` (`image\|file\|voice`), `durationMs` | `201` the message |
| `PATCH /leads/:id/messages/:messageId` | `{ "text": "..." }` | `200` the message, `edited: true`. Only your own text messages |
| `DELETE /leads/:id/messages/:messageId` | none | `204`. Removed for everyone. Only your own messages |
| `POST /leads/:id/calls` | none | `201` a message with `kind: "call"` (the app opened the phone's dialer; no call audio goes through the server) |

How the customer's side arrives (SMS reply, email reply or a web page) is an **open question** (section 7).

---

### 3.4 Media tab (feed, stories, create, social)

Who is a "user" here is an open question (section 7). The app is written so that **businesses** post, follow, like and comment; if viewers get accounts later nothing in these shapes changes.

**40. GET /feed**: reels and posts, newest first, followed accounts first. `?limit=&cursor=`.
```json
[{ "id": "r1", "kind": "reel", "businessId": "b1", "business": "Brightside Dental", "handle": "@brightsidedental",
   "category": "Health & Medical", "reviewer": "Emma Clarke", "caption": "Painless, friendly and they explained every step.",
   "duration": "0:48", "rating": 5, "views": 3200, "likes": 412, "comments": 28, "hue": "#2F8FE0",
   "liked": false, "saved": false, "following": true, "verified": true,
   "mediaUrl": "https://cdn.example.com/r1.mp4", "isVideo": true, "thumbnailUrl": "https://cdn.example.com/r1.jpg",
   "edits": null, "when": "2h" }]
```
`kind`: `testimonial` (a customer video from `/videos` that was shared), `reel`, `post`. `rating` and `reviewer` only for testimonials (0 and empty otherwise). `edits` is the optional edit settings JSON the app saved (filters, text and so on) if the server did not render them into the file; null when the file is final. Posts from blocked accounts are left out.

**41. GET /stories**: one entry per business, newest first; your own entry first with `"mine": true`. Expired stories (older than 24 hours) are not returned.
```json
[{ "id": "b1", "business": "Brightside Dental", "category": "Health & Medical", "seen": false, "mine": false,
   "items": [{ "hue": "#2F8FE0", "text": "New patients welcome this month", "when": "2h",
              "mediaUrl": null, "isVideo": false, "edits": null }] }]
```
**42. POST /stories/:groupId/seen**: marks that business's stories seen. `204`.

**43. POST /posts** (multipart) creates a post, reel or story. Fields: `file`, `kind` (`post | reel | story`), `caption` (up to 2200), `duration` (`"0:48"`), `isVideo` (`true|false`), `edits` (JSON string, optional).
Response `201`: the created feed item (shape of `/feed`). For a story, a story item. Posting your own media needs a verified business: `403 verification_required`. A video may need processing before it can play: return `status: "processing"` on the item and the finished `mediaUrl` later (the app shows a placeholder until `mediaUrl` is set).
**44. DELETE /posts/:id**: only the author (or ViewRec staff). `204`.

**45 and 46. Like and save**: `PUT /posts/:id/like` and `DELETE` the same path; the same for `/save`. Idempotent (`PUT` twice is fine). Response `200`: `{ "liked": true, "likes": 413 }` and `{ "saved": true }`. The app updates the screen first and rolls back if the call fails.

**47 to 49. Comments**
```json
// GET /posts/:id/comments  (oldest first)
[{ "id": "c1", "author": "Sophie Walker", "text": "Great work!", "when": "2h", "mine": false }]
```
`POST /posts/:id/comments` `{ "text": "..." }` (up to 1000 characters) → `201` the comment, and the post's `comments` count goes up by one. `DELETE /comments/:id` (your own, or the post's owner) `204`.

**50. Follow**: `PUT /accounts/:businessId/follow` and `DELETE`. Response `{ "following": true, "followers": 120 }`.

**51. GET /profiles/:handle** (a business's public profile)
```json
{ "businessId": "b1", "handle": "@brightsidedental", "name": "Brightside Dental", "category": "Health & Medical",
  "about": "Friendly family dentists.", "verified": true, "followers": 120, "following": true,
  "avatarUrl": null, "posts": [ /* feed items */ ], "testimonials": 14, "rating": 4.9 }
```
`:handle` may be the handle or the business id. `posts` are the business's own posts and reels (feed item shape), newest first; add `followingCount`, `mine` and `blocked` (whether the caller blocked this business) to the example above. A blocked or blocking business returns `404`.
**52. GET /profiles/:handle/followers** (and **52b. GET /profiles/:handle/following**, same shape): `[{ "businessId": "b2", "name": "Northgate Autos", "handle": "@northgateautos", "following": false }]`.

**53. POST /reports** (needed for App Store approval)
```json
{ "targetType": "post", "targetId": "r1", "reason": "spam", "note": "optional" }
```
`targetType`: `post | comment | profile | message`. `reason`: `spam | abusive | misleading | inappropriate | other`. `201 { "id": "rep_1" }`. Reported items go to a review queue; ViewRec staff must be able to hide an item.
**54. Block**: `GET /blocks` lists the caller's blocked businesses (`[{ businessId, name, handle, category }]`), `PUT /blocks/:businessId` blocks and `DELETE` unblocks. Blocked accounts disappear from the feed, stories, comments and search for the blocker. `204`.

---

### 3.5 Website tools in the app

All 🆕 or ✅ over existing tables. Shapes are exactly the app's models.

**Gallery** (`gallery_items`, `gallery_folders`). Limits: 100 MB a file, 2 GB a business.
```json
// GET /gallery/folders
[{ "id": "f1", "name": "Roof jobs" }]
// GET /gallery/items
[{ "id": "g1", "name": "Skylight install.mp4", "kind": "video", "bytes": 50331648, "folderId": "f1",
   "url": "https://cdn.example.com/g1.mp4", "when": "3 days ago" }]
```
`kind`: `image | video | document`. `POST /gallery/folders` `{ "name" }` → `201` folder. `POST /gallery/upload` (multipart: `file`, `kind`, `folderId` optional) → `201` item. `PATCH /gallery/items/:id` `{ "folderId": "f2" }` (or `null`). `DELETE /gallery/items/:id` `204`.

**Contact bundles** (`contact_bundles`, `contact_bundle_members`). A bundle has 10 to 20 customers. Pro and up.
```json
// GET /bundles
[{ "id": "b1", "name": "Roof replacements 2026", "memberIds": ["1","2","3","4","5","6","7","8","9","10"], "lastSent": "12 days ago" }]
```
`POST /bundles` and `PUT /bundles/:id` take `{ "name", "memberIds": [...] }` and return the bundle (`422` if not 10 to 20). `DELETE /bundles/:id` `204`. `POST /bundles/:id/send` `{ "subject", "body" }` → `200 { "sent": 10, "skipped": 0 }`, through the send gate. `403 plan_required` below Pro.

**Calendar**: `GET /calendar?month=2026-11`
```json
[{ "id": "c1", "date": "2026-11-19T00:00:00Z", "title": "Reminder 2 due", "kind": "reminder", "who": "Sarah Mitchell" }]
```
`kind`: `invite | reminder | automation | bundle`. Past items are what was sent; future items are what is scheduled.

**Review templates** (`templates`)
```json
[{ "id": "t1", "name": "Roof job", "questions": ["What did we do for you?", "How was the team on the day?"], "isDefault": true }]
```
`POST /templates` and `PUT /templates/:id` take `{ "name", "questions": [...] }` (1 to 6 questions). `DELETE /templates/:id` (keep at least one). `PUT /templates/:id/default`.

**Verification** (`business_documents`, `account_blue_tick`)
```json
{ "status": "in_review", "note": "A ViewRec reviewer will check your documents.",
  "docs": [{ "id": "d1", "name": "Certificate.pdf", "status": "pending", "when": "just now" }] }
```
`status`: `none | in_review | verified | rejected`. Doc `status`: `pending | approved | rejected`. `POST /verification/documents` (multipart `file`) → the whole verification object. The app explains that posting your own media needs `verified`.

**Review requests** (`review_access_requests`)
```json
[{ "id": "a1", "name": "Tom Harding", "email": "tom@example.com", "message": "I would like to leave a review.", "when": "2 h ago", "status": "pending" }]
```
`status`: `pending | approved | declined`. `POST .../approve` sends that person their recording link; `POST .../decline`. Both `204`.

**Referrals**
```json
{ "link": "https://viewrec.com/join/HARTLEY-7K2", "code": "HARTLEY-7K2", "creditCents": 4900,
  "referred": [{ "name": "Brightside Dental", "status": "paid", "creditCents": 4900, "when": "2 weeks ago" }] }
```
`status`: `signed up | paid`. Credit is earned when the referred business pays.

**Video settings**: `{ "subtitles": true, "watermark": true }`. `PUT` same body; turning `subtitles` on needs Pro, turning `watermark` off needs Pro Plus (`403 plan_required`).

**Embeds** (`embeds`). Pro and up.
```json
[{ "id": "e1", "name": "Home page wall", "layout": "wall", "count": 6, "created": "10 days ago" }]
```
`POST /embeds` `{ "name", "layout": "wall|carousel", "count": 3..12 }` → `201` embed. The app builds the snippet as `<script src="https://viewrec.com/api/embed/{id}" async></script>` (the existing website route), so keep that route working. `DELETE /embeds/:id` `204`.

**Support** (the website's support chat with ViewRec staff, `support_threads`/`support_messages`). One thread per business. Same message object as the Inbox, but here `from: "business"` is you and `from: "customer"` is the ViewRec team.
`GET /support/thread` → messages oldest first. `POST /support/thread` `{ "text" }` → `201`. `POST /support/thread/attachment` (multipart `file`, `kind`, `durationMs`) → `201`. `PATCH`/`DELETE /support/thread/messages/:id` as in the Inbox. Delivered and read marks come from the staff side opening the thread.

**Security**
```json
{ "twoFactor": false, "devices": [{ "id": "d1", "device": "This phone", "place": "Manchester, UK", "when": "Active now", "current": true }] }
```
`PUT /security/two-factor` `{ "enabled": true }`. `DELETE /security/devices/:id` signs out one session (not the current one). `POST /security/sign-out-others` signs out all other sessions. These are the website's session list; the phone's own session appears with `current: true`.

**Workspaces** (`workspace_members`)
```json
[{ "id": "w1", "name": "Hartley Roofing", "role": "Owner", "current": true }, { "id": "w2", "name": "Brightside Dental", "role": "Member", "current": false }]
```
`POST /workspaces/:id/switch` makes it current for this session (then every call acts in that business; the app also sends `X-Workspace-Id`). Permissions inside a workspace are the website's (`workspace-access.ts`).

**Marketing email** `POST /marketing/email`
```json
{ "subject": "A thank you from Hartley Roofing", "body": "Hi, ...", "audience": "all" }
```
`audience`: `all | approved`. Through the send gate. `200 { "sent": 28, "excluded": 3 }` (`excluded` = opted out or contacted in the last 180 days).

---

### 3.6 Customer side (public, no sign-in)

These wrap the website's existing public review routes so the phone and the website behave the same.

**95. GET /public/invites/:token**
```json
{ "business": "Hartley Roofing", "customer": "Sarah Mitchell", "script": ["line 1", "line 2", "line 3"], "questions": ["What did we do for you?"] }
```
`404 { "error": "Invalid or expired link" }` for an unknown, expired or opted-out token. (Today this data comes from `/review/[token]`.)

**96. POST /public/invites/:token/video** (multipart; wraps `/api/review/submit-video`)

| Field | Type | Notes |
| --- | --- | --- |
| `video` | file | `video/mp4` (phone) or `video/webm`, up to 100 MB |
| `consent` | JSON string | `{"agreed":true,"agreedAt":"2026-11-23T14:34:29Z","singleSession":true,"platform":"android"}` |
| `duration` | string | `"01:48"` |
| `rating` | string | `"1"` to `"5"` |
| `avatar` | string | empty, or `fox / owl / bear / robot / star / leaf` (camera-shy mode; Pro and up) |

`400` if `consent.agreed` is not true; `404` bad token. Success `201 { "id": "v_3b40f2c0" }`. The video appears in `/videos` as `pending`, the customer becomes `recorded`, the consent record is stored with the video.

**97. POST /public/invites/:token/written** (wraps `/api/review/submit`)
```json
{ "rating": 5, "text": "They turned up when they said they would...",
  "consent": { "agreed": true, "agreedAt": "2026-11-23T14:34:29Z", "singleSession": true, "platform": "android" } }
```
`201`. `400` if consent is not true or the text is shorter than 10 characters.

---

## 3b. Added after the first draft (screens built since)

**A1. POST /ai/transcribe** (multipart): `file` (the recorded video), `durationMs`, optional `script` (planned wording, used to improve accuracy). Speech to text with timing. Returns an array of caption lines the app lets the user edit:
`[ { "startMs": 0, "endMs": 3200, "text": "Hi, I am so glad you stopped by." } ]`. Keep each line short (one sentence or about 8 words). The app burns the edited captions into the video on the phone.

**A2. POST /ai/script** `{ "topic": "Free roof inspections", "tone": "friendly|professional|punchy", "business": "Hartley Roofing" }` returns `{ "script": "..." }`. A short spoken script (about 30 to 60 seconds). Rate limit per business.

**A3. POST /auth/password** `{ "currentPassword", "newPassword" }`. 204 on success, 400 `wrong_password` or `weak_password`. Other signed-in devices are signed out.

**A4. POST /account/export** starts a data export and emails the owner a download link. 202.

**A5. POST /account/delete** schedules account deletion in 30 days (owner only); the owner can cancel by contacting support. 202.

**A6. PATCH and DELETE /customers/:id** are described at endpoints 26 and 26b (edit and remove from the phonebook; the app always confirms before removing).

**A7. Groups** reuse the existing `/bundles` endpoints. The Phonebook screen creates a bundle from the people the user ticks.

---

## 4. Values used by the app

| Thing | Values |
| --- | --- |
| Customer `status` | `suggested`, `approved`, `invited`, `recorded`, `skipped` |
| Testimonial `status` | `pending`, `approved`, `published` |
| Lead `status` | `new`, `contacted`, `won`, `lost` |
| Lead `source` | `Directory`, `Review page`, `Website embed` |
| Message `kind` | `text`, `image`, `file`, `voice`, `call` |
| Message `status` | `sent`, `delivered`, `read` |
| Feed item `kind` | `testimonial`, `reel`, `post` |
| Post `status` | `scheduled`, `published`, `failed` |
| Plan | `Standard`, `Pro`, `Pro Plus`, `Managed` |
| Billing `status` | `trial`, `active`, `past_due`, `cancelled` |
| Verification `status` | `none`, `in_review`, `verified`, `rejected` |
| Platform ids | `google`, `web`, `fb`, `ig`, `yt`, `tt`, `li`, `pin` |
| Automation `channel` | `sms_email`, `sms`, `email`, `whatsapp` |

---

## 5. New database tables (reference)

From the website audit, plan section 3.2. Everything is **additive**: new tables and new nullable columns only.

| Table | Used by endpoints |
| --- | --- |
| `sessions.client` (new nullable column) | 2 to 5, 88 to 91 |
| `device_tokens` | 8, 9 |
| `feature_flags` | 1 |
| `media_assets` | 36, 43, 58, 73, 85 |
| `social_posts` | 40 to 44 |
| `social_likes`, `social_saves` | 45, 46 |
| `social_comments` | 47 to 49 |
| `social_follows` | 50, 52 |
| `story_views` | 41, 42 |
| `public_profiles` (or columns on `directory_profiles`) | 51, 52 |
| `inbox_conversations`, `inbox_messages` | 34 to 39 (add `status`, `edited_at`, `deleted_at`, `kind`) |
| `reports`, `user_blocks` | 53, 54 |

Support (83 to 87) can reuse `support_threads` and `support_messages` with new nullable columns for attachments, `edited_at` and `deleted_at`.

---

## 6. Suggested build order

| Phase | What | Endpoints |
| --- | --- | --- |
| 1 | Foundations: `/meta`, feature flags, mobile sign-in with tokens, staging copy of the database | 1 to 9 |
| 2 | **Read-only** screens over existing data (low risk) | 10 to 12, 14, 16, 18, 20, 23, 24, 30, 32, 66, 67, 72, 74, 77, 78, 80, 88, 92 |
| 3 | Write actions that reuse website logic and checks | 13, 15, 17, 19, 21, 22, 25 to 29, 31, 33, 55 to 65, 68 to 71, 73, 75, 76, 79, 81, 82, 89 to 91, 93, 94 |
| 4 | Customer recording over the existing public routes | 95 to 97 |
| 5 | Uploads and media processing (poster picture and an MP4 copy) | 43 (files), 36, 85 |
| 6 | Report, block and public profiles (before any public social content) | 51 to 54 |
| 7 | Media: posts, stories, feed, likes, saves, comments, follows | 40 to 50 |
| 8 | Inbox and Support conversations with attachments, edit, delete and receipts | 34 to 39, 83 to 87 |
| 9 | Push notifications and deep links (Android App Links, iOS Universal Links on `/review/*`, `/r/*`, `/capture/*`) | 8, 9 |

Every phase should be tried on the staging copy first, and every endpoint that sends to a customer must go through the send gate.

---

## 7. Decisions the boss must make (the app is ready for either answer)

1. **Payments in the app.** Apple and Google require their own billing for subscriptions bought inside an app. The app currently opens a website link (`/billing/checkout-link`). Keep that, or add store billing?
2. **Sign-up.** The website creates accounts only through the pre-sales form. Should the app open `/reserve`, or create accounts itself?
3. **Who is a user in the Media tab?** Businesses only, or also viewers and customers with their own accounts?
4. **How the customer's side of the Inbox arrives** (SMS reply, email reply, or a web page). Two-way SMS needs an inbound webhook from the SMS provider.
5. **Server video processing.** Can the host run `ffmpeg` and a background job for the poster picture and MP4 copy, or should an outside service be used?
6. **Plan limits for Media, push and Inbox.** All plans, or Pro and up?
7. **Calls inside the app** (over the internet). The app opens the phone's own dialer today. A real in-app call needs a calling provider and a token endpoint; it is not in this list.

---

## 8. Please send back

- The **base URL of a staging copy** that a phone can reach over HTTPS.
- A **test business login** (email and password) with some sample data, and a **valid test invitation token**.
- A short list of anything in this file that cannot be done as written, with the change you would prefer.
- Optionally an OpenAPI file generated from your `zod` types for `/api/v1`. The app's changes will follow it.

**For the app side:** to point the app at the real API, build with `--dart-define=API_URL=https://<host>` (without the `/api/v1` part). Without it the app runs on sample data.
