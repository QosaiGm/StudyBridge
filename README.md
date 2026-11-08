# StudyBridge

**ندرس معاً، وننمو معاً.** A private, Arabic-first study space built with Flutter and Supabase.

## Requirements

- Flutter 3.47.9 or newer on stable (Dart 3.13.7).
- Android SDK for Android builds; Flutter Web for browser builds.
- A Supabase project for real sign-up, login, and password reset.

## Run locally

From `D:\StudyBridge`:

```powershell
flutter pub get
flutter run -d chrome --dart-define-from-file=.env.local.json
```

For Android, replace `-d chrome` with a connected Android device ID. Use the Supabase URL and publishable/anon key from your project's Connect dialog or Project Settings → API Keys. Never put a service-role key in the app.

Apply the migration in `supabase/migrations/` from the Supabase SQL Editor or with `supabase db push`. It creates the private profile table, owner-only RLS policies, and an Auth trigger that creates profiles for new accounts.

In Supabase Authentication → URL Configuration, add the web origin and Android deep link to allowed redirect URLs before enabling password recovery in production.

Without Supabase defines, the Arabic authentication screen runs as a setup preview and explains what's missing. It does not fake sign-in.

See [PROGRESS.md](PROGRESS.md) for phase status.


## Academic management (Phase 2)

The academic screens now read and write private subjects, lectures, tasks, and planner sessions through Supabase. Apply the next migration by opening `supabase/migrations/202611070002_academic_management.sql` and pasting the **SQL contents** into Supabase Dashboard → SQL Editor → New query → Run. Do not paste the file path. This migration enables owner-only RLS policies and ties linked rows to subjects owned by the same user.

After migration, sign in and use the bottom navigation → موادي. The tab bar provides subjects, tasks, weekly planner, and lectures. Add/edit/delete and completion actions are saved to Supabase.

## Personal focus timer (Phase 3)

The personal timer saves session timestamps in Supabase so the countdown can be recovered after suspension or reopening. It supports pause, resume, finish, cancel, optional subject association, and a recent session history. The personal timer requires the current schema in `supabase/studybridge_full_schema.sql` (or migrations 202611070003 and later). Paste SQL contents into Supabase SQL Editor, not the file path.

## Supabase setup in one query

For a new setup or to apply all current app tables at once, use `supabase/studybridge_full_schema.sql`. Copy the entire file contents into Supabase Dashboard → SQL Editor → New query → Run. Replacing the text in the SQL Editor does not remove database tables, and this script does not delete data. It is safe to rerun. The numbered files in `supabase/migrations/` remain the incremental history; use the full schema file when you want the complete setup in one paste.

The complete schema file is updated as features are implemented. The current `supabase/studybridge_full_schema.sql` includes profiles, private academic records, personal focus sessions, private study spaces, invitations, shared focus sessions, member chat and presence, private Little Moments, user settings, notification preferences, and the verified app-admin role, plus their server-side functions, RLS, and Realtime publication setup. Paste the whole file and run it once to bring an existing project up to the current app schema; it does not drop existing rows.

### App administrator account

The app-wide admin role is stored separately from private study-space owner/member roles. Create and verify the account through the normal Auth flow, then use `supabase/admin_grant_template.sql` privately in the Supabase SQL Editor to grant its verified email app-admin access. Replace the template placeholder with the address there; don't commit an email address or password to the repository. The `public.is_app_admin()` function is available for admin-only RLS policies and features.

## GitHub Pages deployment

The `.github/workflows/deploy-pages.yml` workflow builds the Flutter web release and publishes it to GitHub Pages on pushes to `main`. Before the first deployment, add repository Actions secrets named `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`, then set **Settings → Pages → Build and deployment → Source** to **GitHub Actions**. The workflow calculates the correct web base path for a repository site and leaves URL routing on Flutter's default hash strategy.

## Private voice rooms (Phase 4)

The app uses LiveKit for audio-only rooms. Cameras are not requested or published. The Flutter app asks Supabase Edge Functions for a 10-minute room token after sign-in; the function checks the caller's `study_space_members` row before issuing a token that can publish microphone audio and subscribe to other members. The LiveKit API secret never belongs in Flutter or `.env.local.json`.

To enable voice rooms:

1. Create a LiveKit Cloud project and copy its WebSocket URL, API key, and API secret.
2. In Supabase Dashboard → Edge Functions → Secrets, add `LIVEKIT_URL`, `LIVEKIT_API_KEY`, and `LIVEKIT_API_SECRET`.
3. Deploy `supabase/functions/livekit-token/` as the `livekit-token` function. The function validates the caller's Supabase session itself, so the Dashboard's legacy JWT verification toggle must be off; `supabase/config.toml` keeps that setting off on CLI deploys. Run `supabase functions deploy livekit-token --project-ref YOUR_PROJECT_REF` from `D:\StudyBridge`.
4. Confirm the latest `supabase/studybridge_full_schema.sql` is applied so study-space membership RLS is available to the function.

The room lets each participant stop/start microphone publication and mute incoming audio independently. Android/iOS also expose speaker output routing. In browsers, use the room's **تفعيل صوت الآخرين** button if autoplay is blocked; the microphone can be retried with its button after allowing browser access. The function validates the user's Supabase session and space membership itself; the Dashboard's legacy JWT toggle should remain off when using this custom validation.

## Personal progress and Little Moments (Phase 5)

The **حسابي** navigation destination opens the progress page with personal focus totals, daily and weekly study time, completed tasks and lectures, a study streak, a seven-day chart, and per-subject lecture completion. Shared focus totals are counted once per shared session, not once per member. Little Moments are private to study-space members and are protected by RLS. Open the settings icon there to edit your display name, optional avatar URL, week start, notification categories, reminder lead time, and quiet hours. These notification choices are stored securely; device delivery and Firebase Cloud Messaging still need setup. Run the latest complete schema before using the new settings and moments tables.

The current app theme is a dark midnight-plum surface with lavender and champagne accents, shared across sign-in, study, collaboration, and progress screens.


