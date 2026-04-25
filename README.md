# Present Evidence

A Flutter application for lawyers to present evidence collaboratively. Teams can manage cases, upload evidence, create highlighted sections, and run local or WebRTC-powered remote presentations.

## Features

- **Authentication** – Sign in with Google or Apple via Supabase Auth
- **Teams** – Create teams, invite members, assign admin roles (including admins not on the team)
- **Cases** – Create cases and assign a team; shared and private evidence sections
- **Evidence** – Upload PDFs, videos, and images to Supabase Storage (backed by Google Cloud Storage)
- **Highlights** – Mark important sections of evidence:
  - **Video** – Clip start/end time + optional zoom region
  - **PDF** – Page range + optional zoom region
  - **Image** – Zoom region
  - **Zoom overlay** – Full content shown at reduced opacity, zoomed region displayed prominently in front
- **Presentations** – Build ordered slide decks from evidence and highlights; add private presenter notes and public comments between slides
- **Local Presentation** – Immersive slideshow mode with presenter notes
- **Remote Presentation** – WebRTC-powered session:
  - Presenter starts session → shareable URL generated
  - Viewers open URL, enter display name, presenter approves/rejects
  - Slide changes broadcast to all viewers in real-time via Supabase Realtime
  - Presenter can jump to any slide, view pending viewers, and show presenter notes

## Tech Stack

| Concern | Library |
|---------|---------|
| Framework | Flutter 3.19+ |
| Auth + Database | [Supabase](https://supabase.com/) |
| Storage | Supabase Storage (Google Cloud Storage backend) |
| State management | Riverpod 2 |
| Navigation | go_router |
| WebRTC | flutter_webrtc |
| PDF viewer | pdfx |
| Video player | video_player + chewie |
| Image viewer/zoom | photo_view |
| File picker | file_picker |

## Setup

### 1. Create a Supabase project

1. Go to [supabase.com](https://supabase.com/) and create a new project.
2. In the SQL editor, run the migration in `supabase/migrations/20240101000000_initial_schema.sql`.
3. Create a storage bucket named **`evidence`** (private).
4. Configure Google and Apple OAuth providers in **Authentication → Providers**.

### 2. Configure the app

Pass values at build time:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Or edit `lib/main.dart` and replace the `defaultValue` strings directly.

### 3. Android deep links

The `android/app/src/main/AndroidManifest.xml` already contains intent filters for:
- `io.supabase.presentevidence://login-callback/` – OAuth redirect
- `present-evidence://watch/<sessionId>` – Viewer join link

### 4. iOS deep links

Add to `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>io.supabase.presentevidence</string>
      <string>present-evidence</string>
    </array>
  </dict>
</array>
```

### 5. Run

```bash
flutter pub get
flutter run
```

## Project Structure

```
lib/
├── main.dart                         # Entry point; Supabase init
├── app.dart                          # MaterialApp.router
├── core/
│   ├── models/                       # Pure data classes
│   │   ├── app_user.dart
│   │   ├── case.dart
│   │   ├── evidence.dart
│   │   ├── highlight.dart            # ZoomRegion lives here
│   │   ├── presentation.dart
│   │   └── team.dart
│   ├── services/                     # Business logic / API calls
│   │   ├── auth_service.dart
│   │   ├── case_service.dart
│   │   ├── evidence_service.dart
│   │   ├── highlight_service.dart
│   │   ├── presentation_service.dart
│   │   ├── storage_service.dart
│   │   ├── supabase_service.dart
│   │   ├── team_service.dart
│   │   └── webrtc_service.dart       # Signalling + WebRTC peer connections
│   ├── router/
│   │   └── app_router.dart
│   └── theme/
│       └── app_theme.dart
└── features/
    ├── auth/                         # Login, profile
    ├── cases/                        # Case list & detail
    ├── evidence/                     # Upload, view (PDF/video/image)
    ├── highlights/                   # Highlight editor, zoom selector/overlay
    ├── presentations/                # Builder (drag & drop order, notes)
    ├── present/                      # Local slideshow + remote presenter/viewer
    └── teams/                        # Team list & member management
```

## Database Schema

See `supabase/migrations/20240101000000_initial_schema.sql` for the full schema including Row Level Security policies.

**Key tables:**
- `users` – mirrors `auth.users`
- `teams` / `team_members` – team management with roles
- `cases` – legal cases assigned to a team
- `evidence` – uploaded files; `is_shared` controls team visibility
- `highlights` – important sections with optional zoom region (JSONB)
- `presentations` / `presentation_items` – ordered slide decks
- `remote_sessions` – active WebRTC presentation sessions
