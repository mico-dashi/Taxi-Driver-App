# Going live in Albania

The app works out of the box in **demo mode**. To take real rides you need a backend, SMS login, a map provider and store accounts. Follow these steps in order.

## 1. Backend (Supabase), about 15 minutes

1. Create a project at [supabase.com](https://supabase.com). Choose the **Frankfurt (eu-central-1)** region, the closest to Albania.
2. Install the [Supabase CLI](https://supabase.com/docs/guides/cli), then from the repository root run:
   ```bash
   supabase init            # only if the CLI asks for it; keep the existing files
   supabase link --project-ref YOUR_PROJECT_REF
   supabase db push                      # creates tables, security rules, functions
   psql "$DATABASE_URL" -f supabase/seed.sql   # tariffs + TAKSI30 promo
   ```
   (Or paste both files into the dashboard's **SQL Editor** and run them.)
3. Enable **pg_cron** (Database → Extensions) and schedule the clean-up job:
   ```sql
   select cron.schedule('expire-requests', '* * * * *', 'select public.expire_stale_requests()');
   ```
4. Copy the **Project URL** and **publishable key** (Settings → API) and build the app with them:
   ```bash
   flutter build apk --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_KEY=...
   ```
   To have GitHub build it for you, add both as repository secrets named `SUPABASE_URL` and `SUPABASE_KEY`.

## 2. SMS login for +355 numbers

Supabase → Authentication → Providers → **Phone**: enable it and connect an SMS provider that delivers to Albanian numbers (Twilio, Vonage or MessageBird). Budget roughly €0.05–0.10 per SMS.
For testing without sending SMS, add test numbers with a fixed code under *Phone → Test OTPs*.

## 3. Approving drivers

Drivers register in the app, but **cannot receive rides until you approve them**. Check their documents (driving licence, vehicle registration, municipality taxi licence, insurance), then run in the SQL Editor:
```sql
update vehicles set approved = true where plate = 'AA 482 TR';
```
To block someone: `update profiles set is_blocked = true where phone = '+35569…';`

## 4. Business model: selling to drivers

The database supports a **monthly subscription** per driver (the app tells drivers "no commission, every lek is yours"):
```sql
-- turn the requirement on
update app_settings set require_driver_subscription = true;
-- a driver paid for a month
insert into driver_subscriptions (driver_id, valid_until)
select id, now() + interval '30 days' from profiles where phone = '+35569…'
on conflict (driver_id) do update set valid_until = excluded.valid_until;
```
Drivers without an active subscription get "Your subscription has expired" when they try to send an offer. Collect the fee in cash, by bank transfer, or later through a payment provider.

Change prices any time without updating the app:
```sql
update fare_settings set per_km = 110 where category_id = 'standard';
```

## 5. Maps, routing and address search

The defaults use free public OpenStreetMap servers. They are fine for testing, but their usage policies **do not allow a commercial app with many users**. Before launch, pick one:

| Service | Option | Pass it with |
|---|---|---|
| Map tiles | MapTiler, Stadia Maps, or Thunderforest (free tiers available) | `--dart-define=TILE_URL=https://…/{z}/{x}/{y}.png?key=…` |
| Routing | Self-hosted OSRM with the Albania extract from Geofabrik (a small €5/month server is enough) | `--dart-define=ROUTING_URL=https://your-osrm` |
| Address search | Self-hosted Nominatim, or a paid geocoder with a compatible API | `--dart-define=GEOCODING_URL=https://…` |

If routing or search is unreachable, the app still works: it estimates routes and uses its built-in list of Albanian places.

## 6. Card, Apple Pay and Google Pay payments

Cash works everywhere and is the default. In live mode, card and wallet options stay hidden until you connect a payment provider, because charging cards needs a merchant account. Options for an Albanian business:
- **POK** (Albanian payment app/API), or the e-commerce gateway of **Raiffeisen, BKT, Credins or OTP** bank
- **Stripe**, which requires a company registered in a supported country (Albania is not supported directly)

Once integrated, build with `--dart-define=CARD_PAYMENTS=true`. The card form only keeps brand and last 4 digits. The full card number must go to the provider's SDK (tokenisation), never to your server.

## 7. Legal checklist (Albania)

Not legal advice. Check these with an Albanian lawyer or accountant:
- **Company** registered with QKB (NIPT) to sell subscriptions and sign contracts with drivers.
- **Fiscalisation**: taxi rides must be fiscalised (e-invoice / fiscal receipt through the tax authority's system). Decide whether drivers issue receipts with their own fiscal devices or whether the platform integrates fiscalisation.
- **Taxi licences** come from each municipality (Bashkia). Only accept drivers with a valid licence (the app's document checklist covers this).
- **Personal data**: register with the Information and Data Protection Commissioner (IDP), publish a privacy policy (phone numbers, GPS locations, ride history), and state how long data is kept.
- **Terms of use** for passengers and a **driver agreement** (subscription, cancellations, behaviour, insurance).

## 8. Publishing the apps

| Store | Cost | Notes |
|---|---|---|
| Google Play | $25 once | Create a release signing key (`keytool`), configure `android/app/build.gradle.kts` signing, upload `flutter build appbundle`. Declare location usage in the Play Console. |
| Apple App Store | $99 / year | Needs a Mac with Xcode. Set the bundle ID and team in Xcode, then `flutter build ipa`. The location usage text (Albanian + English) is already in `Info.plist`. |

Also replace the default Flutter launcher icon with your logo (e.g. with the `flutter_launcher_icons` package).

## 9. Before the first real ride

- [ ] Supabase project with migration + seed applied, pg_cron job scheduled
- [ ] SMS provider working for +355 numbers
- [ ] Map tiles / routing / search provider configured
- [ ] Support phone and email set in `app/lib/core/config.dart`
- [ ] At least a few approved drivers online in the launch city
- [ ] Privacy policy and terms published, company and fiscal questions settled
- [ ] Test a full ride with two phones: one passenger account, one driver account
