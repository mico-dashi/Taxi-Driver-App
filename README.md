# Taksi AL: ride-hailing app for Albania 🇦🇱

A complete taxi app for Albania: a **passenger app** and a **driver app** in one codebase, plus a **backend** (database, security rules, real-time offers). It is based on the reference video and adapted for Albania:
Albanian language (English too), prices in **Lek (L)**, cash payments, Albanian phone numbers (+355), Albanian number plates, cities and landmarks, and local emergency numbers.

> **Shqip:** Aplikacion i plotë taksie për Shqipërinë: aplikacion për pasagjerët, aplikacion për shoferët dhe server. Çmimet janë në lekë, pagesa me para në dorë ose kartë, dhe shoferët bëjnë oferta si te inDrive. Mund ta provoni menjëherë në **modalitetin demo** (kodi SMS: `123456`).

---

## What's inside

### Passenger app (same flow as the video)
| Screen | What it does |
|---|---|
| Login | Albanian mobile number (+355 6X…) and a 6-digit SMS code |
| Home | Greeting, **"Where would you go?"**, Standard / Luxury / Van cards with the nearest car's ETA, a **30% first-ride promo** (`TAKSI30`), the list of available cars with driver, rating and price per km |
| Where to? | Search (works offline with 37 popular Albanian places + online address search), current location, recent and saved places (Home/Work) |
| **1. Route** | Map with the route, pickup/destination (tap to change, swap button), km and minutes |
| **2. Payment** | Cash (default, since most Albanians pay cash), cards, Apple Pay / Google Pay |
| **3. Car** | Choose Standard / Luxury / Van with the exact fare for this trip; **raise or lower your offer** (inDrive style) |
| Finding driver | Radar animation, drivers found around you, **offers from drivers with a 15-second countdown**, Decline / Accept, "Looking for another driver…" |
| Ride | "Ride confirmed" → **Driver on the way** (live car on the map, ETA, progress bar) → **Driver has arrived** → trip in progress. Call, chat, cancel with a reason, share trip, safety button (112 / 129 / 127) |
| Trip complete | Fare summary, "pay the driver X L in cash", 5-star rating, tip, comment |
| Bookings / Chat / Profile | Ride history with receipts, chat with the driver and WhatsApp support, payment methods, promo codes, saved places, language, "Become a driver" |

### Driver app (what you sell to taxi drivers)
- Register the vehicle (make, model, **Albanian plate**, service type)
- **Go online / offline**; the driver's live GPS is shared with passengers
- Incoming requests with pickup, destination, distance, the passenger's fare and payment type
- **Accept at the passenger's price or counter-offer** (+100 / +200 / +500 L)
- Navigate with **Google Maps or Waze**, then "I've arrived" → "Start trip" → "Complete trip" → "Collect X L in cash"
- **Earnings** dashboard (today, last 7 days, trips), document checklist (licence, registration, municipality taxi licence, insurance)

### Backend (Supabase: PostgreSQL + Auth + Realtime)
- `supabase/migrations/…_init.sql`: tables, **row-level security** (passengers only see their own rides; a driver who lost the bid can't see the ride or the chat), and server functions:
  - `accept_offer` is atomic: only one driver can win a ride
  - `send_offer` rejects offers below the passenger's fare and offers from unapproved cars
  - `update_ride_status` only allows valid steps (arrived → in progress → completed)
  - `rate_ride` keeps the driver's average rating; `apply_promo` handles first-ride-only codes
  - `nearby_drivers`, `driver_earnings` (Europe/Tirane time zone), `expire_stale_requests`
- Drivers **cannot approve themselves** or change their own rating; an admin approves vehicles
- Optional **monthly subscription** check for drivers (the business model, see below)

### Albania-specific pricing (editable in the `fare_settings` table)
| Type | Base | Per km | Per min | Minimum |
|---|---|---|---|---|
| Standard | 300 L | 100 L | 10 L | 400 L |
| Luxury | 600 L | 220 L | 20 L | 1.000 L |
| Van (7 seats) | 500 L | 160 L | 15 L | 800 L |

Night tariff +20% (22:00–06:00), 2.500 L minimum for Rinas airport trips, and fares rounded to 50 L so cash change is easy.

---

## Try it now (demo mode)

Demo mode needs **no server and no accounts**. Drivers, offers and the car moving on the map are all simulated on the phone, so you can show the app to taxi drivers anywhere. Log in with any Albanian number and the code **123456**. Pick "I drive a taxi" to see the driver app.

```bash
cd app
flutter pub get
flutter run            # Android phone / emulator, iPhone, or: flutter run -d chrome
```

**Without a computer:** every push to GitHub runs the **CI** workflow (`.github/workflows/ci.yml`). It tests everything and builds an **Android APK** (and a web version). Open the repository's **Actions** tab → latest run → *Artifacts* → download `taksi-al-android` and install `app-release.apk` on any Android phone.

## Go live

See **[docs/GOING_LIVE.md](docs/GOING_LIVE.md)** for step-by-step instructions: create the Supabase project, SMS login for +355 numbers, map provider, approving drivers, publishing to Google Play / App Store, payments, and the legal checklist for Albania.

In short:
```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
  --dart-define=SUPABASE_KEY=sb_publishable_...
```

## Re-branding for another company

Change `app/lib/core/config.dart` (name, tagline, support phone/email, promo code, emergency numbers, map/routing servers) and the colours in `app/lib/core/theme.dart`. All text is in `app/lib/core/strings.dart` (Albanian + English). Replace the launcher icons in `app/android/app/src/main/res/mipmap-*` and `app/ios/Runner/Assets.xcassets`.

## Project structure

```
app/                         Flutter app (Android, iOS, web)
  lib/core/                  config, theme, translations, Albanian places, formatting
  lib/models/                data types (ride, offer, driver…)
  lib/services/              backend interface, demo simulator, Supabase backend,
                             routing (OSRM), geocoding (Nominatim), GPS, pricing
  lib/screens/auth/          login, SMS code, profile setup
  lib/screens/passenger/     home, bookings, chat, profile
  lib/screens/booking/       where-to search, Route → Payment → Car
  lib/screens/ride/          finding driver + offers, live ride, trip complete
  lib/screens/driver/        drive (online/requests/active ride), earnings, vehicle
  test/                      unit, simulated end-to-end and UI tests
supabase/
  migrations/                database schema + security + server functions
  seed.sql                   tariffs and the TAKSI30 promo code
  tests/                     end-to-end SQL test of the whole booking flow
docs/GOING_LIVE.md           launch guide for Albania
```

## Tests

```bash
cd app && flutter analyze && flutter test          # 23 tests
PGHOST=... PGUSER=... ./supabase/tests/run_local.sh # full booking flow on PostgreSQL
```
