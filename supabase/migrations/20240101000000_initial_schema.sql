-- Present Evidence – Supabase schema
-- Run this in the Supabase SQL editor or via `supabase db push`

-- ─── Extensions ────────────────────────────────────────────────────────────
create extension if not exists "uuid-ossp";

-- ─── Users ─────────────────────────────────────────────────────────────────
-- Mirrors auth.users; populated on first login.
create table if not exists public.users (
  id          uuid primary key references auth.users(id) on delete cascade,
  email       text not null,
  display_name text,
  avatar_url  text,
  created_at  timestamptz not null default now()
);
alter table public.users enable row level security;
create policy "Users can read any user profile" on public.users
  for select using (true);
create policy "Users can update own profile" on public.users
  for update using (auth.uid() = id);
create policy "Users can insert own profile" on public.users
  for insert with check (auth.uid() = id);

-- ─── Teams ─────────────────────────────────────────────────────────────────
create table if not exists public.teams (
  id          uuid primary key default uuid_generate_v4(),
  name        text not null,
  created_by  uuid not null references public.users(id),
  created_at  timestamptz not null default now()
);
alter table public.teams enable row level security;

create table if not exists public.team_members (
  team_id   uuid not null references public.teams(id) on delete cascade,
  user_id   uuid not null references public.users(id) on delete cascade,
  role      text not null check (role in ('admin', 'member')) default 'member',
  joined_at timestamptz not null default now(),
  primary key (team_id, user_id)
);
alter table public.team_members enable row level security;

-- Allow members to see teams they belong to
create policy "Team members can read their team" on public.teams
  for select using (
    exists (
      select 1 from public.team_members
      where team_id = public.teams.id and user_id = auth.uid()
    )
  );
create policy "Team admins can modify team" on public.teams
  for update using (
    exists (
      select 1 from public.team_members
      where team_id = public.teams.id and user_id = auth.uid() and role = 'admin'
    )
  );
create policy "Authenticated users can create teams" on public.teams
  for insert with check (auth.uid() = created_by);
create policy "Team admins can delete team" on public.teams
  for delete using (
    exists (
      select 1 from public.team_members
      where team_id = public.teams.id and user_id = auth.uid() and role = 'admin'
    )
  );

create policy "Team members can read members" on public.team_members
  for select using (
    exists (
      select 1 from public.team_members tm2
      where tm2.team_id = public.team_members.team_id and tm2.user_id = auth.uid()
    )
  );
create policy "Team admins can manage members" on public.team_members
  for all using (
    exists (
      select 1 from public.team_members tm2
      where tm2.team_id = public.team_members.team_id and tm2.user_id = auth.uid()
        and tm2.role = 'admin'
    )
  );
-- Allow creator to insert themselves
create policy "Any user can join as first member" on public.team_members
  for insert with check (auth.uid() = user_id);

-- ─── Cases ─────────────────────────────────────────────────────────────────
create table if not exists public.cases (
  id          uuid primary key default uuid_generate_v4(),
  name        text not null,
  description text,
  team_id     uuid references public.teams(id) on delete set null,
  created_by  uuid not null references public.users(id),
  created_at  timestamptz not null default now()
);
alter table public.cases enable row level security;

create policy "Creator or team members can read cases" on public.cases
  for select using (
    auth.uid() = created_by
    or (
      team_id is not null and exists (
        select 1 from public.team_members
        where team_id = public.cases.team_id and user_id = auth.uid()
      )
    )
  );
create policy "Creator can insert cases" on public.cases
  for insert with check (auth.uid() = created_by);
create policy "Creator can update cases" on public.cases
  for update using (auth.uid() = created_by);
create policy "Creator can delete cases" on public.cases
  for delete using (auth.uid() = created_by);

-- ─── Evidence ──────────────────────────────────────────────────────────────
create table if not exists public.evidence (
  id              uuid primary key default uuid_generate_v4(),
  case_id         uuid not null references public.cases(id) on delete cascade,
  uploaded_by     uuid not null references public.users(id),
  name            text not null,
  type            text not null check (type in ('pdf', 'video', 'image')),
  storage_path    text not null,
  thumbnail_path  text,
  is_shared       boolean not null default false,
  file_size_bytes bigint,
  mime_type       text,
  created_at      timestamptz not null default now()
);
alter table public.evidence enable row level security;

create policy "Owner or team can read evidence" on public.evidence
  for select using (
    auth.uid() = uploaded_by
    or (
      is_shared and exists (
        select 1 from public.cases c
        left join public.team_members tm on tm.team_id = c.team_id
        where c.id = public.evidence.case_id and (c.created_by = auth.uid() or tm.user_id = auth.uid())
      )
    )
  );
create policy "Uploader can insert evidence" on public.evidence
  for insert with check (auth.uid() = uploaded_by);
create policy "Uploader can update evidence" on public.evidence
  for update using (auth.uid() = uploaded_by);
create policy "Uploader can delete evidence" on public.evidence
  for delete using (auth.uid() = uploaded_by);

-- ─── Highlights ─────────────────────────────────────────────────────────────
create table if not exists public.highlights (
  id            uuid primary key default uuid_generate_v4(),
  evidence_id   uuid not null references public.evidence(id) on delete cascade,
  name          text not null,
  type          text not null check (type in ('imageZoom', 'pdfPages', 'videoClip')),
  clip_start_ms int,
  clip_end_ms   int,
  start_page    int,
  end_page      int,
  zoom_region   jsonb,
  created_at    timestamptz not null default now(),
  created_by    uuid not null references public.users(id)
);
alter table public.highlights enable row level security;

create policy "Evidence owner can manage highlights" on public.highlights
  for all using (
    exists (
      select 1 from public.evidence e where e.id = public.highlights.evidence_id
        and (e.uploaded_by = auth.uid() or e.is_shared)
    )
  );

-- ─── Presentations ───────────────────────────────────────────────────────────
create table if not exists public.presentations (
  id          uuid primary key default uuid_generate_v4(),
  case_id     uuid not null references public.cases(id) on delete cascade,
  name        text not null,
  created_by  uuid not null references public.users(id),
  created_at  timestamptz not null default now()
);
alter table public.presentations enable row level security;

create policy "Case access can manage presentations" on public.presentations
  for all using (
    exists (
      select 1 from public.cases c
      left join public.team_members tm on tm.team_id = c.team_id
      where c.id = public.presentations.case_id
        and (c.created_by = auth.uid() or tm.user_id = auth.uid())
    )
  );

create table if not exists public.presentation_items (
  id                uuid primary key default uuid_generate_v4(),
  presentation_id   uuid not null references public.presentations(id) on delete cascade,
  order_index       int not null,
  evidence_id       uuid references public.evidence(id) on delete set null,
  highlight_id      uuid references public.highlights(id) on delete set null,
  presenter_notes   text,
  public_comment    text,
  constraint one_target check (
    (evidence_id is not null and highlight_id is null)
    or (evidence_id is null and highlight_id is not null)
  )
);
alter table public.presentation_items enable row level security;

create policy "Presentation access can manage items" on public.presentation_items
  for all using (
    exists (
      select 1 from public.presentations p
      join public.cases c on c.id = p.case_id
      left join public.team_members tm on tm.team_id = c.team_id
      where p.id = public.presentation_items.presentation_id
        and (c.created_by = auth.uid() or tm.user_id = auth.uid())
    )
  );

-- ─── Remote Sessions ─────────────────────────────────────────────────────────
create table if not exists public.remote_sessions (
  id                uuid primary key,
  presentation_id   uuid not null references public.presentations(id) on delete cascade,
  current_index     int not null default 0,
  is_active         boolean not null default true,
  created_at        timestamptz not null default now()
);
alter table public.remote_sessions enable row level security;

create policy "Presenter can manage sessions" on public.remote_sessions
  for all using (
    exists (
      select 1 from public.presentations p
      join public.cases c on c.id = p.case_id
      left join public.team_members tm on tm.team_id = c.team_id
      where p.id = public.remote_sessions.presentation_id
        and (c.created_by = auth.uid() or tm.user_id = auth.uid())
    )
  );
-- Anyone can read a session (to join as viewer)
create policy "Anyone can read active sessions" on public.remote_sessions
  for select using (is_active = true);

-- ─── Storage ─────────────────────────────────────────────────────────────────
-- Create the evidence bucket via Dashboard or CLI:
-- supabase storage create evidence --public=false
