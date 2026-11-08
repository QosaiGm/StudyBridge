# StudyBridge progress

Updated: 2026-11-08

## Phase 1 — Foundation

- [x] Flutter Android and Web project in `D:\StudyBridge`.
- [x] Arabic RTL theme and local Arabic font assets.
- [x] Riverpod, GoRouter, and Supabase Flutter setup.
- [x] Arabic sign-in, sign-up, password reset, and starter dashboard.
- [x] Supabase Auth repository and private profiles with owner RLS and Auth trigger.
- [x] Flutter analysis, baseline widget test, and Web build.
- [ ] Live sign-up, login, and password-reset verification.
- [ ] Android compilation; project Gradle 9.3.1 distribution is only partially cached.

## Phase 2 — Academic management

- [x] Private subjects, lectures, tasks, and planner tables with owner RLS.
- [x] Supabase repository and Arabic create/edit/delete/complete flows.
- [x] Supabase migration applied (owner confirmed).
- [x] Flutter analysis, existing tests, and Web build.
- [ ] Authenticated CRUD verification; direct API verification could not resolve Supabase DNS in this environment.
- [ ] Focused repository and widget tests.

## Phase 3 — Focus system

- [x] Personal timestamp-backed timer with recovery, pause/resume/finish/cancel, subject association, and history.
- [x] Shared focus session foundation with server-side state controls, server clock, and Realtime updates.
- [x] Timer calculation unit tests.
- [x] Flutter analysis, all tests, and Web build.
- [x] Personal timer schema included in the all-in-one SQL script previously confirmed by the owner.
- [ ] Apply the latest all-in-one schema to add private spaces and shared focus, then verify with two authenticated accounts.

## Phase 4 — Collaboration

- [x] Private study spaces, owner/member roles, and membership checks.
- [x] Expiring multi-use invite codes and authenticated acceptance.
- [x] Real online/studying/away presence, heartbeat, and stale-status handling.
- [x] Private Realtime text chat with the latest 100 messages.
- [x] LiveKit audio-only room client, microphone controls, Android permission, and 10-minute membership-checked Edge Function tokens.
- [x] `livekit-token` deployed; LiveKit Cloud secrets configured by owner.
- [ ] Exercise microphone calling with two authenticated accounts/devices.

## Phase 5 — Personal experience

- [x] Dark midnight-plum theme with lavender and champagne accents across the app.
- [x] Personal/shared study statistics, seven-day visualization, streak, task and lecture completion, and subject progress.
- [x] Private Little Moments with member-only visibility and creator-only deletion.
- [ ] Apply the new Little Moments SQL migration / updated complete schema and verify with two space members.
- [x] Profile display name and avatar URL settings, with shared-space member names kept in sync.
- [x] Per-category notification preferences, reminder lead time, quiet hours, and week-start preference stored privately in Supabase.
- [ ] Device notification delivery, local scheduling, and Firebase Cloud Messaging; the project has no notification SDK configured and no new package was added.

## Phase 6 — Deployment and hardening

- [x] Release Android manifest includes Internet and microphone permissions.
- [x] Ignore local environment files and Android signing credentials.
- [x] Baseline release review: all 17 public tables have RLS, and the Web client bundle contains no Supabase secret-key or service-role credential patterns.
- [x] Local Git repository initialized on `main`.
- [x] GitHub Pages build/deployment workflow and dependency update schedule prepared.
- [ ] Android build and device verification; Gradle 9.3.1 is not cached locally.
- [ ] Performance review.
- [x] First GitHub Pages deployment is live at https://qosaigm.github.io/StudyBridge/; Actions run 42524699137 succeeded.
- [x] Secure app-wide admin role table/helper and a private verified-email grant template, separate from study-space owner/member roles.

## Configuration and known issues

- Supabase URL and publishable key are in Git-ignored `.env.local.json`.
- The latest all-in-one script is `supabase/studybridge_full_schema.sql`; it is rerunnable and preserves existing rows. It includes chat, presence, Little Moments, profile display-name sync, user settings, and notification preferences. Rerun the updated full file to update an existing project.
- The full schema creates the app-admin role mechanism; grant a verified account privately with `supabase/admin_grant_template.sql`. It does not create a password or bypass email verification.
- LiveKit credentials are set in Supabase Edge Function secrets. The deployed `livekit-token` function performs custom session and membership validation; the Dashboard's legacy JWT verification switch is off as requested by its configuration guidance.
- Configure Supabase email confirmation and password-reset redirects before testing those flows.
- Android build is blocked pending the project Gradle 9.3.1 distribution; JDK 17 is installed.
