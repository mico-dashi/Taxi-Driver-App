# Running Rent AL on free services

Everything the app needs runs on free plans, without GitHub Actions:

| Part | Free service | What it does | Free limit |
|---|---|---|---|
| Database, login, photos, realtime | **Supabase** (project `rent-al`) | Stores users, cars, bookings, chats and car photos | 500 MB database, 1 GB photos, 50,000 users a month |
| Website | **Netlify** (`netlify.toml`) | Builds the live app at `/` and the demo at `/demo/` on every push to `main` | 300 build minutes and 100 GB traffic a month |
| Keep the database awake | Netlify scheduled function (`netlify/functions/keep-alive.mjs`) | One tiny read a day, because free Supabase projects pause after a week without activity | Included |
| Android app | **Codemagic** (`codemagic.yaml`) | Runs the tests and builds `rent-al.apk` (live) and `rent-al-demo.apk` (demo) | 500 build minutes a month |
| Login emails | **Gmail SMTP** | Sends the 6-digit login code | About 500 emails a day |
| Maps and address search | **OpenStreetMap** tiles and Nominatim | Shows maps and finds addresses | Fine for a small app; switch to a paid provider when traffic grows |
| Car brand logos | **Simple Icons** (CC0) | Brand filters and badges | Built into the app |
| Demo car photos | **Wikimedia Commons** (CC BY-SA) | Photos of the demo cars, credited in the app | Free with credit |

## Setup (about 20 minutes, one time)

### 1. Merge the code
On GitHub, open pull request #1 and click **Merge pull request**. Merging still works while GitHub Actions is locked. Only the red checks are affected.

### 2. Website on Netlify
1. Go to https://app.netlify.com and click **Sign up → GitHub**.
2. Click **Add new site → Import an existing project → GitHub**, then choose **mico-dashi/Taxi-Driver-App**.
3. Netlify reads `netlify.toml` by itself: leave the settings as they are and click **Deploy**. The first build takes about 5 minutes because it installs Flutter; later builds are faster.
4. Go to **Site configuration → Change site name** and pick a name, e.g. `rent-al`. Your app is then at https://rent-al.netlify.app and the demo at https://rent-al.netlify.app/demo/.

### 3. Supabase settings
1. **Authentication → URL Configuration**:
   - Set **Site URL** to `https://rent-al.netlify.app`.
   - Under **Redirect URLs**, add `https://rent-al.netlify.app/**`.
2. **Authentication → Emails → SMTP Settings**: turn on custom SMTP with your Gmail address.
   - **Host:** `smtp.gmail.com`
   - **Port:** `587`
   - **Username:** your Gmail address
   - **Password:** a Gmail **App Password**, created at https://myaccount.google.com/apppasswords (2-Step Verification must be on)
3. **Authentication → Emails → Templates**: in both **Magic Link** and **Confirm signup**, add `{{ .Token }}` to the body, for example:
   `<h2>Kodi juaj Rent AL</h2><p>Kodi: <strong>{{ .Token }}</strong></p>`
4. Log in once in the app. Then, in the **SQL Editor**, make yourself admin:
   `update profiles set role = 'admin' where email = 'your@email.com';`

### 4. Android app on Codemagic
1. Go to https://codemagic.io, click **Sign up with GitHub**, then **Add application** and choose **mico-dashi/Taxi-Driver-App**.
2. Codemagic finds `codemagic.yaml`. Click **Start new build → Rent AL Android**.
3. After about 15 minutes, download **rent-al.apk** (live) and **rent-al-demo.apk** from the build page. Send the APK to any Android phone and install it (allow "install unknown apps"). It builds again by itself on every push to `main`.

## When you grow
- **Google Play** costs a one-time $25; the Apple App Store costs $99 a year.
- **Your own domain** (e.g. rent.al) costs about €10–15 a year. Connect it in Netlify under **Domain management**, and switch the email sender from Gmail to Resend or Brevo (both have free tiers) so emails come from your domain.
- **Supabase Pro** ($25 a month) makes sense once you pass the free limits or need daily backups.
