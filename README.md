# BharatGPS TaskManager — Technician App (Flutter)

A native Android wrapper around the live technician portal. The app loads the
existing, fully-tested web technician app in a full-screen WebView, so behavior
is 100% identical to the web version, while giving you an installable APK.

**Loads:** `https://salmon-goldfish-110661.hostingersite.com/app/login.html`

## What's wired up
- Full-screen WebView (no browser chrome)
- Location permission + in-page geolocation (Get Location / Navigate / Reached)
- Camera permission
- External links (WhatsApp, tel:, mailto:, Google Maps navigation) open in their
  native apps
- Android hardware back button navigates WebView history

## Getting the APK (no local setup needed)
1. Every push to `main` triggers the **Build APK** GitHub Action.
2. Open the **Actions** tab → latest run → download the
   **bharatgps-technician-apk** artifact.
3. Unzip → `app-release.apk` → install on the phone (allow "install from unknown
   sources").

You can also trigger a build manually from Actions → Build APK → Run workflow.

## Package
`com.bharatgps.techapp` · label **BharatGPS Technician**

## Changing the start URL
Edit `kStartUrl` in `lib/main.dart`.
