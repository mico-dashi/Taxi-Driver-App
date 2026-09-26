# Rent AL: car rental between people in Albania 🇦🇱

A peer-to-peer car rental app for Albania with **two modes in one app**:

- **"Gjej makinë me qira" (Find a car to rent)**: search by place and dates, compare cars on a list or map, send a booking request, and **offer your own price** if you like.
- **"Kam makinë për qira" (I have a car for rent)**: list your cars, receive requests, **accept, decline or counter-offer**, hand over the car and track your earnings.

It comes with a **backend** (database, security rules, realtime updates) that makes sure a car can never be double-booked. Built for Albania: Albanian (and English), prices in **Lek (L)**, cash at pickup, Albanian phone numbers (+355) and plates, and cities from Tirana and Rinas airport to Durrës, Vlorë, Sarandë and Ksamil.

> **Shqip:** Aplikacion për makina me qira mes njerëzve. Qiramarrësi kërkon sipas vendit dhe datave dhe mund të ofrojë çmimin e vet; pronari e pranon, e refuzon ose bën kundërofertë. Provojeni menjëherë në **modalitetin demo** (kodi SMS: `123456`).

> The app started as a taxi app (inDrive-style offers). That version is kept in the Git history at commit `30c064e`.

## Design

**Liquid glass** in racing red `#EC0618`, graphite `#212325` and near-black `#010101`, with the Manrope font.
- Every page sits on a dark backdrop with soft red light. Cards, buttons, the floating menu, the slide button and bottom bars are frosted glass: the background is blurred and brightened, with a light sheen and a bright rim.
- **Car brands**: 32 brand logos (Volkswagen, Mercedes-Benz, BMW, Audi, Toyota, Hyundai, Kia, Škoda, Renault, Dacia, Fiat, Opel, Ford, Peugeot, Jeep, Porsche, Tesla and more). They appear as a brand filter on home and search, as badges on every car, and as a brand picker when owners add a car. Logos come from [Simple Icons](https://simpleicons.org) (CC0). They are trademarks of their owners and are shown only to identify a car's make.
- **Real photos**: owners add up to 8 photos per car. Cards show the cover photo under a glass info panel, and the car page has a swipeable gallery. Cars without photos show their brand logo glowing over the model name.
- Welcome screen with a hero car and slide-to-start, a "Top trends" carousel, a "Choose a car" list, and a car page with a spec grid and slide to "Book now".

## How it works

**Renter**
1. **Search**: choose where and when (pick-up and return day and hour), filter by Economy / SUV / Luxury / Van, sort by distance or price, switch between **list and map** (price pins).
2. **Car page**: specs (gearbox, fuel, seats, km per day), the owner and their rating, where the car is parked (map + directions), rental terms (deposit, minimum days, fuel policy), and the full price for your dates.
3. **Book in 3 steps: Dates → Payment → Offer**. Pick it up yourself or have it delivered (if the owner offers delivery), pay by cash or card, and offer the listed price or less (down to 70%).
4. **Answer**: the owner accepts, declines or sends a **counter-offer** that you can accept with one tap.
5. **Handover and return**: "I picked up the car" → "I returned the car" → review the car and owner. Chat and call the owner at any time.

**Owner**
1. **Add a car**: make, model, year, Albanian plate, colour, type, gearbox, fuel, seats, price per day (with a suggestion), deposit, minimum days, km per day, location, optional delivery with a fee, and a description. Hide or show it any time.
2. **Requests inbox**: see who asks, the dates, their offer against your price, the total, payment method and message. **Accept / Counter / Decline** straight from the card.
3. **Handovers and returns**: upcoming handovers, cars rented out now, history.
4. **Earnings**: this month, days rented, average per day, all time.

**Pricing** (same formula in the app and on the server): price per day × days, **−10% for 7+ days, −20% for 28+ days**, the first-rental promo **QIRA20** (−20%), plus delivery, rounded to 100 L. The deposit is shown separately and refunded at return.

## Try it now (demo mode)

Demo mode needs **no server**. It includes 15 cars with owners in Tirana, Rinas, Durrës, Vlorë, Sarandë and Ksamil. Simulated owners answer your requests (accept, or counter-offer when you offer less), and in owner mode simulated renters send requests for your cars. Log in with any Albanian number and the code **123456**.

```bash
cd app
flutter pub get
flutter run            # Android / iPhone, or: flutter run -d chrome
```

**Without a computer:** the **CI** workflow tests everything and builds an **Android APK** (Actions tab → latest run → *Artifacts* → `rent-al-android`). The **Web demo (GitHub Pages)** workflow publishes the web app with the real map at **https://mico-dashi.github.io/Taxi-Driver-App/**. One-time setup: **Settings → Pages → Source: GitHub Actions**; it updates on every change to `main`.

## Go live

See **[docs/GOING_LIVE.md](docs/GOING_LIVE.md)**: backend setup, SMS login, approving cars, insurance and legal points for renting cars in Albania, payments, and publishing to the stores.

## Re-branding

`app/lib/core/config.dart` holds the name, tagline, support contacts, promo code, search radius and map server; `app/lib/core/theme.dart` the colours (`AppColors`) and the font (Manrope, SIL Open Font License, in `app/assets/fonts`); `app/lib/core/strings.dart` all texts in Albanian and English. Replace the launcher icons in `app/android/app/src/main/res/mipmap-*` and `app/ios/Runner/Assets.xcassets`.

## Project structure

```
app/                         Flutter app (Android, iOS, web)
  assets/fonts/              Manrope font (OFL licence)
  lib/core/                  config, theme, translations, Albanian places, formatting
  lib/models/                cars, bookings, users
  lib/services/              backend interface, demo simulator, Supabase backend,
                             pricing, address search, GPS
  lib/screens/auth/          welcome, login, SMS code, choose mode
  lib/screens/renter/        home & search, results (list/map), car page, booking steps, my rentals
  lib/screens/owner/         requests inbox, my cars, add/edit car, earnings, account
  lib/screens/common/        booking status page (both sides), chats, payment, places, profile
  lib/widgets/               design kit: car drawings, slide button, pill menu, cards
  test/                      unit, simulated booking flows and UI tests
supabase/
  migrations/                schema, security rules and booking functions
  seed.sql                   car categories and the QIRA20 promo
  tests/                     end-to-end SQL test of the rental flow
docs/GOING_LIVE.md           launch guide for Albania
```

## Tests

```bash
cd app && flutter analyze && flutter test          # 21 tests
PGHOST=... PGUSER=... ./supabase/tests/run_local.sh # rental flow on PostgreSQL
```
