# Going live in Albania

The app works out of the box in **demo mode**. To take real bookings you need a backend, SMS login, a map provider and store accounts, and you must settle the insurance and legal questions below **before** the first real rental.

## Status: the live backend is set up

> **All on free services:** see [FREE_SETUP.md](FREE_SETUP.md). It covers Netlify for the website, Codemagic for the Android app, and Gmail for the login emails, and none of it needs GitHub Actions.

- **Supabase project `rent-al`** (Frankfurt, free plan): https://cihhvvhhkgqgqbuwhjwh.supabase.co
- All migrations are applied (tables, security rules, booking functions, `car-photos` storage bucket, email login) and the seed is loaded (categories, QIRA20). The Supabase security advisor findings are fixed.
- Unanswered requests expire automatically every 15 minutes (pg_cron job `expire-requests`).
- `app/config/live.json` holds the project URL and its **publishable** key. It is safe to ship: the database rules protect the data. The CI and Pages workflows build the live app with it:
  - `rent-al.apk` is the live Android app, and `rent-al-demo.apk` is the offline demo.
  - GitHub Pages serves the live web app at https://mico-dashi.github.io/Taxi-Driver-App/ and the demo at `/demo/`.
- **Login**: live users log in with a 6-digit code sent by **email** (free), then add their mobile number for handovers. When an SMS provider is connected, build with `--dart-define=LOGIN=phone` to switch to SMS.

### What only you can do (about 10 minutes)

1. **Email code template.** In the Supabase dashboard, go to Authentication → Emails → Templates. Replace the body of **Magic Link** *and* **Confirm signup** with:
   ```html
   <h2>Kodi juaj Rent AL</h2>
   <p>Shkruani këtë kod në aplikacion: <strong>{{ .Token }}</strong></p>
   <p>Your Rent AL code: <strong>{{ .Token }}</strong></p>
   ```
2. **Email sending.** Supabase's built-in mail service only sends a few emails per hour, which is enough for testing but not for real users. Add a free SMTP provider (Resend, Brevo or Mailgun) under Authentication → Emails → SMTP settings.
3. **Site URL.** Under Authentication → URL Configuration, set the Site URL to `https://mico-dashi.github.io/Taxi-Driver-App/`.
4. **GitHub Actions and Pages.** Fix the Actions block on your GitHub account (see the pull request comment), then set Settings → Pages → Source to **GitHub Actions**. The live web app and the APKs are then built on every push to `main`.
5. **Become admin.** Log in to the live app once, then run this in the SQL editor:
   `update profiles set role = 'admin' where email = 'you@example.com';`
   Approve each car after checking its papers:
   `update cars set approved = true where plate = 'AA 482 TR';`

## 1. Backend (Supabase), about 15 minutes

1. Create a project at [supabase.com](https://supabase.com). Choose the **Frankfurt (eu-central-1)** region, the closest to Albania.
2. Install the [Supabase CLI](https://supabase.com/docs/guides/cli), then from the repository root run:
   ```bash
   supabase init            # only if the CLI asks for it; keep the existing files
   supabase link --project-ref YOUR_PROJECT_REF
   supabase db push                              # tables, security rules, booking functions
   psql "$DATABASE_URL" -f supabase/seed.sql     # car categories + QIRA20 promo
   ```
   (Or paste both files into the dashboard's **SQL Editor** and run them.)
3. Enable **pg_cron** (Database → Extensions) and schedule the clean-up of unanswered requests:
   ```sql
   select cron.schedule('expire-requests', '*/15 * * * *', 'select public.expire_stale_requests()');
   ```
4. Copy the **Project URL** and **publishable key** (Settings → API) and build the app with them:
   ```bash
   flutter build apk --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_KEY=...
   ```
   To have GitHub build it for you, add both as repository secrets named `SUPABASE_URL` and `SUPABASE_KEY`.

What the server guarantees:
- **No double bookings.** The database refuses a second confirmed booking that overlaps an existing one for the same car, even if two owners' taps arrive at the same moment.
- Renters cannot offer below 70% of the listed price (change `min_offer_percent` in `app_settings`), or book shorter than the owner's minimum.
- Only the two people in a booking can see it and its chat. Owners cannot approve their own cars or change their ratings.
- Unanswered requests expire after 24 hours (`request_ttl_hours`).

## 2. SMS login for +355 numbers

Supabase → Authentication → Providers → **Phone**: enable it and connect an SMS provider that delivers to Albanian numbers (Twilio, Vonage or MessageBird). Budget roughly €0.05–0.10 per SMS. For testing without sending SMS, add test numbers with a fixed code under *Phone → Test OTPs*.

## 3. Approving cars and renters

New cars are **hidden until you approve them**. Check the registration (leja e qarkullimit), insurance and the owner's ID, then run:
```sql
update cars set approved = true where plate = 'AA 482 TR';
```
Renters should show a valid driving licence at handover (the app reminds both sides). You can mark verified licences with `update profiles set licence_verified = true where phone = '+35569…';`, and block someone with `update profiles set is_blocked = true where phone = '+35569…';`.

## 4. Insurance and legal checklist (read this first)

Not legal advice. Discuss these with an Albanian lawyer, an insurer and an accountant before launch:
- **Insurance.** A standard Albanian motor policy (TPL) often does **not** cover renting a private car to strangers. You need either a partner insurer offering per-rental cover, or to work only with owners whose cars are insured for rental. This is the most important decision for a peer-to-peer rental business.
- **Licensing.** Commercial car rental (rent-a-car) may require a business licence and vehicles registered for rental use. Clarify whether private owners can rent through the platform, or whether you start with licensed rent-a-car businesses and small fleets (the app works for both).
- **Company and taxes.** A company registered with QKB (NIPT). Rental income must be declared, and **fiscal receipts** (fiscalisation) are required for payments. Decide whether owners issue them or the platform does.
- **Contract.** A short rental agreement accepted by both sides for every booking: deposit, fuel, damage, fines, late return and cancellation rules.
- **Personal data.** Register with the Information and Data Protection Commissioner (IDP) and publish a privacy policy (phone numbers, ID/licence checks, locations, booking history).

## 5. Business model

Pick one (or combine them), all supported by the data model:
- **Monthly subscription for owners**: turn it on with `update app_settings set require_owner_subscription = true;` and record payments in `owner_subscriptions`. Cars of owners without an active subscription stop receiving requests.
- **Commission per booking**: the confirmed `total` of every booking is stored, so a commission (e.g. 10–15%) can be invoiced monthly from the `bookings` table.

## 6. Maps and address search

The defaults use free public OpenStreetMap servers. They are fine for testing, but their usage policies **do not allow a commercial app with many users**. Before launch, use a tile provider (MapTiler, Stadia Maps, Thunderforest) with `--dart-define=TILE_URL=https://…/{z}/{x}/{y}.png?key=…`, and a geocoder (self-hosted Nominatim or a compatible paid one) with `--dart-define=GEOCODING_URL=…`. Without search, the app still works with its built-in list of Albanian places.

## 7. Card payments and deposits

Cash at pickup works everywhere and is the default. In live mode, card and wallet options stay hidden until you connect a payment provider (**POK**, or the e-commerce gateway of **Raiffeisen, BKT, Credins or OTP**; Stripe needs a company in a supported country). With a provider you can also **pre-authorise the deposit** on the renter's card instead of taking cash. Then build with `--dart-define=CARD_PAYMENTS=true`.

## 8. Car photos

Owners upload photos in the app. The migration `20260927000000_car_photos.sql` creates the public `car-photos` Storage bucket (5 MB per file, JPEG/PNG/WebP). Owners can only write into their own folder. When you approve a car, check that the photos really show that car and its plate.

## 9. Publishing the apps

| Store | Cost | Notes |
|---|---|---|
| Google Play | $25 once | Create a release signing key (`keytool`), configure `android/app/build.gradle.kts` signing, upload `flutter build appbundle`. |
| Apple App Store | $99 / year | Needs a Mac with Xcode. Set the team in Xcode, then `flutter build ipa`. |

## 10. Before the first real rental

- [ ] Supabase project with migration + seed applied, pg_cron job scheduled
- [ ] SMS provider working for +355 numbers
- [ ] Insurance solution agreed, rental agreement text ready
- [ ] Map tiles / search provider configured
- [ ] Support phone and email set in `app/lib/core/config.dart`
- [ ] First cars approved, privacy policy and terms published
- [ ] A full rental tested with two phones: one renter account, one owner account
