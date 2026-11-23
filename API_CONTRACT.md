# ViewRec mobile app - API contract

This is exactly what the Flutter app calls. The app already has a working client for every endpoint below
(`lib/repo.dart`, class `ApiRepo`) and an in-memory fake (`MockRepo`) that returns the same shapes. If the backend
matches this document, no app changes are needed.

**Turn the real API on:** `flutter run --dart-define=API_URL=https://api.example.com` (or the same flag on
`flutter build apk`). Without `API_URL` the app uses fake data.

## Conventions

- JSON over HTTPS, UTF-8. Dates and times are display strings in this version (e.g. `"12 days ago"`); see "Open questions".
- Success: `200` with the body shown (or `204`/empty for updates). Create: `201`.
- Errors: any status `>= 400` with `{"error": "Human readable message"}`. The app shows that message to the user.
- Ids are strings.
- **Auth (not built in the app yet):** proposed `Authorization: Bearer <token>` on every business-side endpoint.
  The customer-side `/api/invites/...` endpoints use the invite token in the URL and need no login.
- Timeouts: 10 s for normal calls, 5 min for video upload.

## Business side

### GET /api/overview
Used by: Overview screen.
```json
{
  "testimonials": 7, "videos": 7, "waiting": 1, "averageRating": 5.0,
  "customers": 2, "invitesSent": 31, "reviewPages": 1, "linkedAccounts": 4, "embeds": 0,
  "videoLink": "https://viewrec.com/r/demo"
}
```

### Customers (Business Phonebook)
**GET /api/customers** -> array:
```json
[{ "id": "1", "name": "Sarah Mitchell", "job": "Roof replacement", "date": "12 days ago",
   "reason": "Recent job, replied to your last email", "status": "suggested" }]
```
`status`: `suggested | approved | invited | recorded | skipped`.

**POST /api/customers** body `{ "name": "Jane Smith", "job": "Roof repair", "contact": "+44 7700 900123" }`
-> `201` with the new customer (same shape; status `approved`). `contact` may be a phone number or email.

**PATCH /api/customers/:id** body `{ "status": "approved" }` -> `200`.
Rules: only the statuses above; `skipped` customers must never be invited.

### Testimonials / videos
**GET /api/videos** -> array:
```json
[{ "id": "v1", "name": "Lena Fischer", "job": "Skylight install", "duration": "1:48",
   "quote": "They turned up when they said they would...", "status": "pending", "views": 0,
   "hue": "#3b2a6b", "platforms": ["Google", "Website"], "rating": 5, "written": false,
   "url": "https://cdn.example.com/v1.mp4" }]
```
`status`: `pending | approved | published`. `written: true` = text testimonial (no video). `hue` is a placeholder
thumbnail colour; replace with `thumbnailUrl` when thumbnails exist (tell us and we will add it).

**PATCH /api/videos/:id** body `{ "status": "published", "platforms": ["Google", "Facebook"] }` (either field optional) -> `200`.
Publishing to a platform should only happen when the user explicitly publishes.

### Leads and requests
**GET /api/leads** -> array:
```json
[{ "id": "l1", "name": "Rebecca Shaw", "service": "Roof inspection",
   "message": "Hi, I saw your video reviews...", "when": "12 min ago", "source": "Directory", "status": "new" }]
```
`status`: `new | contacted | won | lost`. `source`: `Directory | Review page | Website embed`.

**PATCH /api/leads/:id** body `{ "status": "contacted" }` -> `200`.

**GET /api/leads/:id/messages** -> the conversation, oldest first:
```json
[{ "id": "m0", "from": "customer", "text": "Hi, I saw your video reviews...", "when": "12 min ago" },
 { "id": "m1", "from": "business", "text": "Thanks - when suits you?", "when": "just now" }]
```
**POST /api/leads/:id/messages** body `{ "text": "Thanks - when suits you?" }` -> `201` with the new message.
Sending a first reply should move a `new` lead to `contacted`.

### Insights
**GET /api/insights**
```json
{ "weeklyViews": [120, 180, 150, 260, 310, 280, 420, 512], "totalViews": 2232, "plays": 1604,
  "linkClicks": 389, "avgWatchPercent": 72, "responseRate": 0.28,
  "byPlatform": [{ "platform": "Google", "views": 940 }, { "platform": "Facebook", "views": 610 }] }
```
`weeklyViews` = the last 8 weeks, oldest first. `responseRate` is 0 to 1 (customers who replied / customers invited).

### Import customers (proposed - the screens exist, the call is not wired yet)
**POST /api/customers/import** `multipart/form-data`: `file` (.csv or .xlsx) and `mapping` JSON string such as
`{"Name":"Customer name","Mobile":"Mobile","Email":"Email address","Job done":"Service","Date":"Completed on"}`
(field -> column header in the file; `Name` is required and at least one of `Mobile` or `Email`).
Response: `{ "rows": 212, "reachable": 143, "excluded": 69, "estimateLow": 12, "estimateHigh": 22 }`. Opted-out people and
duplicates are excluded and counted in `excluded`.

### Publishing
**GET /api/posts**
```json
{ "usedThisMonth": 9, "monthlyLimit": 22,
  "posts": [{ "id": "p1", "title": "Priya Nair - quote card", "platform": "Instagram",
              "when": "Today, 17:30", "status": "scheduled", "reactions": 0 }] }
```
`status`: `scheduled | published | failed`. `platform` is the first word of the platform name used in the app
(Google, Facebook, Instagram, YouTube, TikTok, LinkedIn, Pinterest).

### Connected accounts
**GET /api/accounts** -> object of connected accounts only: `{ "google": "Hartley Roofing · Manchester", "fb": "Hartley Roofing Ltd" }`
Platform ids: `google, web, fb, ig, yt, tt, li, pin`.

**PUT /api/accounts/:platformId** - connect (the real flow will be an OAuth redirect; the app currently just calls this) -> `200`.
**DELETE /api/accounts/:platformId** - disconnect -> `200`.

### Notifications
**GET /api/notifications** -> array:
```json
[{ "id": "n1", "kind": "video", "title": "Lena Fischer recorded a video", "subtitle": "Ready for your approval · 2h ago" }]
```
`kind`: `video | suggestion | views | invite | lead`.

### Plan and billing
**GET /api/billing**
```json
{ "plan": "Pro", "status": "trial", "trialDay": 4, "trialLength": 15,
  "afterTrialNote": "then $49 / month on Standard unless you choose another plan.",
  "billingEmail": "demo@viewrec.com", "hasCard": false,
  "usage": [{ "label": "Social posts", "used": 9, "limit": "22" }],
  "invoices": [{ "title": "Trial activation", "amount": "$1.00", "date": "19 Nov 2026" }] }
```
`status`: `trial | active | past_due | cancelled`. `limit` is a string so it can be a number or text like `"unlimited"`.

### Automations
**GET /api/automations** and **PUT /api/automations** (same shape; PUT replaces the settings):
```json
{ "requestAfterJob": true, "autoInvite": true, "thankYou": true, "reminders": true,
  "autoPublish": false, "politeHours": true, "reminderCount": 2, "gapDays": 3, "channel": "sms_email" }
```
`channel`: `sms_email | sms | email | whatsapp`. `reminderCount` 1-5, `gapDays` 1-10. Plan limits (e.g. Standard = 1 reminder)
should be enforced by the server; return `403` with an `error` message if a plan does not allow a setting.

### Business profile
**GET /api/profile** and **PUT /api/profile**:
```json
{ "name": "Hartley Roofing", "category": "Home & Trades", "phone": "+44 161 496 0123",
  "email": "demo@viewrec.com", "website": "https://hartleyroofing.example",
  "area": "Greater Manchester · 25 miles", "about": "Family-run roofers for over 20 years." }
```
The app checks `name` is not empty and `email` looks valid before sending; the server must validate too.

## Customer side (opened from the invitation link, no login)

**GET /api/invites/:token** -> `{ "business": "Hartley Roofing", "customer": "Sarah Mitchell", "script": ["line 1", "line 2", "line 3"] }`
`404` with `{ "error": "Invalid or expired link" }` if the token is unknown, expired, or the person opted out.

**POST /api/invites/:token/video** - `multipart/form-data`:

| Field | Type | Notes |
| --- | --- | --- |
| `video` | file | `video/mp4` (phone) or `video/webm` (browser). Up to 200 MB. |
| `consent` | JSON string | `{"agreed":true,"agreedAt":"2026-11-23T14:34:29Z","singleSession":true,"platform":"android"}` |
| `duration` | string | e.g. `"01:48"` |
| `rating` | string | `"1"` to `"5"`, the customer's star rating |
| `avatar` | string | empty, or `fox / owl / bear / robot / star / leaf` when the customer chose avatar mode (camera-shy). The server replaces the face with that avatar and keeps the voice. |

Must reject with `400` if `consent.agreed` is not true, `404` for a bad token. On success `201 {"id": "v_3b40f2c0"}`;
the video appears in `/api/videos` as `pending` and the customer moves to `recorded`. Store the consent record with the
video: it is the "verified capture" proof shown to the business.

**POST /api/invites/:token/written** - a written testimonial instead of a video. JSON body:
```json
{ "rating": 5, "text": "They turned up when they said they would...",
  "consent": { "agreed": true, "agreedAt": "2026-11-23T14:34:29Z", "singleSession": true, "platform": "android" } }
```
`201` on success; `400` if `consent.agreed` is not true or the text is shorter than 20 characters. It appears in
`/api/videos` with `written: true`.

## Not in the app yet (will need endpoints later)

Sign-in and sign-up, the $1 trial payment and plan changes, sending invitations and reminders (SMS/email/WhatsApp),
coupons and loyalty rewards, posting to social platforms, embeds and review-page editing, opt-out list,
team members, push notifications, deep links that open the app from an invitation.

## Open questions for the backend developer

1. Auth: bearer tokens or sessions? How does sign-in work (email + password, Google)?
2. Time fields: can the API return ISO 8601 timestamps instead of display strings? The app would format them.
3. Video hosting: signed URLs for playback and thumbnails? Which storage and max file size?
4. Pagination: for lists that can grow (customers, testimonials, leads). Proposed `?limit=&cursor=`.
5. Where do invite tokens come from, and what is the invitation link format (so the app can open it directly)?
