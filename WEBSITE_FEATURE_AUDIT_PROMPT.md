I am building the ViewRec mobile app (Flutter, Android + iOS) on top of the SAME backend and database as the ViewRec website that you built. The app already has many screens, and it has some features the website does not have. Before I connect anything, I need a full, honest inventory of what the website really does, compared against the app, so we can move carefully and never break the website.

Please read your real code and database (routes/pages, controllers, models/migrations, background jobs, cron, webhooks, email/SMS templates, admin tools, plan/billing logic, config). Do not guess and do not invent. If something is not in the code, write "NOT FOUND". If you cannot tell, write "UNKNOWN". Never include real secrets, write <REDACTED>.

# Where the mobile app stands today

DONE in the app (screens and behaviour work, but almost everything runs on SAMPLE DATA, not your backend):
- Welcome, sign-in and "start for $1" screens (UI only, no real login or payment).
- Overview dashboard: hero numbers, quick actions, latest testimonials, get-started checklist, story row.
- Testimonials: video and written reviews, filters, approve and publish (drag a waiting one to Approve).
- Business Phonebook: customers, approve / skip / invite, add contact, import screens with column matching, contact detail.
- Leads and Inbox: requests, conversations, text replies, photos, files and voice notes, swipe to mark read or close, drag a lead to a status.
- Automations, Create content (reviews into posts), Your pages (review page, listing, embed), Publishing (schedule), Connected accounts, Plan and billing, Settings (profile, branding, team, opt-outs, notifications, appearance), Insights, Admin, Additional services (rewards, ads, referrals), help and an assistant screen.
- Customer recording flow opened from an invitation: consent, star rating, video (camera), written, or avatar mode (camera-shy), upload.
- App-only Media tab: stories, a feed of reels and posts, follow, like, save, comment, share, full-screen story and reel viewers.
- App-only Create flow: post, reel and story with a full photo editor and a CapCut-style video editor (trim, split, join clips, speed, volume, filters, colour adjust, text, crop, rotate, music, export).
- Look and feel: light and dark, motion and animations, drag and drop in several places.
- 212 automatic layout tests pass. Android runs on real phones; an iPhone test build installs.

Only these talk to a small PROTOTYPE backend (not yours): phonebook, testimonials list and the customer video upload.

MISSING in the app (needs your backend or more work):
- Connection to YOUR real API and database for every screen.
- Real sign-up, sign-in, sessions, the $1 trial payment, plan changes, invoices.
- Really sending invitations and reminders (SMS, email, WhatsApp), opt-out enforcement, polite hours.
- Posting to social platforms and real OAuth for connected accounts.
- Coupons, loyalty rewards, referrals, ads, managed services (screens only).
- Importing a customer list (screens only), review page and embed editing, team members.
- Push notifications, deep links from an invitation into the app.
- Storing the app-only content: Media posts, reels, stories, comments, follows, likes, saves, and Inbox attachments (files, photos, voice notes). These have no backend anywhere yet.
- Report and block, moderation, business public profiles and follower lists (required before an App Store release).
- Video hosting with playback URLs and thumbnails.
- Anything the website has that the app does not have yet (you will tell me which, below).

# What I need from you (one markdown document, these sections, in this order)

## 1. Website feature inventory
Every feature the website offers, for every kind of user (business owner, staff, customer who records, public visitor, admin). Group by area (account, customers, invitations, testimonials, publishing, pages and embeds, automations, billing, settings, admin, analytics, integrations, background jobs). For each feature give: name, one-line description, where it lives in the code (route/page/file), status (complete / partial / beta / disabled), the tables it reads or writes, the API endpoints behind it, which plan or role can use it, and any third-party service it depends on (email, SMS, payments, storage, social APIs).
Also list: every email and SMS template and when it is sent, every scheduled job or cron, every webhook (in and out), every public page (review page, directory listing, embed widget), every plan limit and who enforces it.

## 2. Comparison with the app
A table with one row per feature (website features AND the app features listed above):
Feature | On the website? | In the app today (screen only / works on sample data / missing) | Backend work needed | Risk
Mark clearly: WEBSITE-ONLY (the app must add it), APP-ONLY (backend must be added), BOTH (just connect it).

## 3. Backend plan for the APP-ONLY features
For each app-only feature (Media stories, reels and posts feed, follows, likes, saves, comments, creating posts/reels/stories with photo and video upload, Inbox attachments and voice notes, report/block, business public profile): propose the database tables or columns, the endpoints (method, path, request, response), where files are stored, thumbnails and video processing, size limits, moderation, and rough effort (small / medium / large).
Rules for the plan:
- ADDITIVE ONLY: new tables, new nullable columns, new endpoints. Do not rename, drop or change anything the website uses today.
- Say how to version the API so the website and the app can change independently (for example /api/v1) and whether to use feature flags so a feature can stay hidden until it is ready.
- Say what must be tested on a staging copy of the database before it touches production.
- Give a safe order to build things in, starting with the smallest and safest.

## 4. Keeping the app in sync with the website
How can I find out when the website changes? Summarise the last 20 meaningful changes (commits or releases) grouped by feature, and recommend a mechanism (a generated OpenAPI file, a changelog, API versioning) so the app can follow every future website update without surprises.

## 5. Priorities
Mark each website-only feature as P0 (needed for launch), P1 (soon after) or P2 (later), with a one-line reason, so we add them in the right order.

## 6. Open questions
Anything you need to decide or confirm with me before building.

Keep it factual and complete. Use tables where a table is clearer. Do not change any code or data while answering, this is read-only.
