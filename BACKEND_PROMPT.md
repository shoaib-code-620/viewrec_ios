I am building the ViewRec mobile app (Flutter, Android + iOS). It must use the SAME backend and database that you already built for the ViewRec website. Please read your actual backend code and database (routes/controllers, models/schema, migrations, middleware, file-upload code, config) and write me one complete API handoff document that I can build the app against. Do not guess and do not invent anything: every endpoint, field and example must come from the real code or database. If something does not exist or you cannot tell, write "NOT FOUND" or "UNKNOWN" for it. Never include real secrets (passwords, API keys, tokens, connection strings), write <REDACTED>.

Give me the answer as ONE markdown document with exactly these sections:

## 1. Overview
- Language and framework, database engine and ORM, how files/videos are stored (disk, S3, Cloudinary, etc.), where it is hosted.
- The BASE URL of the API for production and for staging/local, and whether it is reachable over HTTPS from the internet (a phone must reach it).
- How to run it locally and which environment variables it needs (names only, no values).
- CORS settings and any rate limits.

## 2. Authentication and users
- How sign-up and sign-in work (email + password, Google, magic link, OTP?). Give the exact endpoints, request bodies and responses.
- What a logged-in request must send (header name and format, for example `Authorization: Bearer <jwt>`), how long a token lives, and how to refresh or log out.
- The user/role model: business owner, staff, customer, admin. What each role can do.
- How invitation links and invite tokens work for customers (where tokens come from, expiry, what the link looks like).
- One working example for each, as a curl command.

## 3. Database schema
List every table/collection with columns, types, nullable/default, primary and foreign keys, indexes, and every enum or status value (for example lead status, video status, customer status). Add a short relationship summary (which table points to which).

## 4. Endpoint inventory (everything that exists today)
A table with one row per endpoint: METHOD, path, auth required (yes/no + role), path params, query params, request body or multipart fields (name, type, required), success response (status + a REAL example JSON), error responses, and the tables it reads or writes. Include pagination and sorting rules, date/time format and timezone, and how ids look (number, uuid, string).

## 5. File and video uploads
How uploads work: endpoint, multipart field names, allowed types, max size, where files are stored, how the public/playable URL is built, whether URLs are signed or expire, whether thumbnails are generated, and how long uploads can take (timeouts).

## 6. Match against what the mobile app needs
For EACH item in the list below, tell me: EXISTS (same shape), EXISTS BUT DIFFERENT (show the difference: path, fields, status values), or MISSING. For every MISSING or DIFFERENT item, propose the exact endpoint (method, path, request, response) and the database change it needs, so I can send it back to you to build.

What the app needs (JSON field names are the ones the app already uses; if your names differ, show me the mapping):

A. Business dashboard (login required)
1. GET overview numbers: testimonials, videos, waiting, averageRating, customers, invitesSent, reviewPages, linkedAccounts, embeds, videoLink.
2. Customers (phonebook): list {id,name,job,date,reason,status}; create {name,job,contact}; change status. Statuses: suggested, approved, invited, recorded, skipped. Import from a CSV/XLSX file with a column mapping, returning {rows,reachable,excluded,estimateLow,estimateHigh}.
3. Testimonials/videos: list {id,name,job,duration,quote,status,views,platforms,rating,written,url}; change status (pending, approved, published) and platforms.
4. Leads: list {id,name,service,message,when,source,status}; change status (new, contacted, won, lost); conversation per lead (list messages {id,from,text,when,kind}; send a text message; send an attachment: photo, file or voice note, as multipart, with kind and durationMs). Sending the first reply must move a new lead to contacted.
5. Insights: weeklyViews (last 8 weeks), totalViews, plays, linkClicks, avgWatchPercent, responseRate, byPlatform.
6. Publishing: posts list {id,title,platform,when,status,reactions} plus usedThisMonth and monthlyLimit.
7. Connected accounts: list, connect, disconnect (platform ids: google, web, fb, ig, yt, tt, li, pin).
8. Notifications list {id,kind,title,subtitle}.
9. Billing: plan, status, trial days, usage, invoices; plan change; the $1 trial payment (which payment provider?).
10. Automations settings: get and replace (requestAfterJob, autoInvite, thankYou, reminders, autoPublish, politeHours, reminderCount, gapDays, channel).
11. Business profile: get and replace (name, category, phone, email, website, area, about).
12. Sending invitations and reminders by SMS, email, WhatsApp: what exists?

B. Media tab (public feed, like a small social network)
13. Stories: list per business with items, mark seen, create a story (photo or video upload, caption, 24 hour expiry).
14. Feed of reels and posts: list with business, caption, duration, rating, views, likes, comments, liked/saved/following flags, videoUrl or imageUrl; create a post or reel (file upload, caption, duration, optional edit settings JSON).
15. Follow and unfollow a business; like and unlike; save and unsave; comments list and add.
16. Report and block a post or user, and any moderation.

C. Customer side (no login, opened from the invitation link)
17. Get invite details by token: business name, customer name, script lines.
18. Upload a video testimonial (multipart: video, consent JSON, duration, rating, avatar choice).
19. Submit a written testimonial (rating, text, consent JSON).

D. Not built in the app yet but needed soon
20. Push notifications (device token registration), deep links from an invitation, team members, opt-out list, coupons and rewards, social posting.

## 7. Things I need from you
- A ready-to-use test account (email and password for a business owner) and a valid test invite token, with some sample data, on the staging or production URL.
- An OpenAPI 3 (Swagger) file for the endpoints in section 4, or a Postman collection, at the end of your answer in a code block.
- A short list of known bugs, limits and things that are about to change.

Keep the answer factual and complete. Use tables for sections 3 and 4.
