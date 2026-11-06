-- =====================================================================
--  NAVI · esquema de base de datos (Supabase / Postgres)
--  Pégalo entero en Supabase → SQL Editor → New query → Run.
--  Se puede ejecutar varias veces sin romper nada.
-- =====================================================================

-- Ajustes de cada usuario (URL de Canvas, token, última sincronización)
create table if not exists public.navi_settings (
  user_id          uuid primary key default auth.uid() references auth.users on delete cascade,
  canvas_url       text not null default 'https://campus.europaeducationgroup.es',
  canvas_token     text,
  token_expires_at date,
  last_canvas_sync timestamptz,
  last_sync_id     text,
  updated_at       timestamptz not null default now()
);

-- Asignaturas (vienen de Canvas)
create table if not exists public.navi_courses (
  user_id           uuid not null default auth.uid() references auth.users on delete cascade,
  id                bigint not null,
  name              text not null,
  code              text,
  attendance_pct    numeric,
  attendance_label  text,
  sync_id           text,
  updated_at        timestamptz not null default now(),
  primary key (user_id, id)
);

-- Tareas, exámenes y eventos (de Canvas o añadidos a mano)
create table if not exists public.navi_items (
  user_id        uuid not null default auth.uid() references auth.users on delete cascade,
  id             text not null,                -- 'a:123' tarea Canvas · 'e:456' evento Canvas · 'm:...' manual
  source         text not null check (source in ('canvas', 'manual')),
  course_id      bigint,
  course_name    text,
  title          text not null,
  kind           text not null default 'task' check (kind in ('task', 'exam', 'event')),
  kind_override  text check (kind_override in ('task', 'exam', 'event')),
  due_at         timestamptz,
  all_day        boolean not null default false,
  url            text,
  description    text,
  submitted      boolean not null default false,  -- entregada en Canvas
  no_submission  boolean not null default false,  -- Canvas no admite entrega online
  done           boolean not null default false,  -- tick manual
  done_at        timestamptz,
  hidden         boolean not null default false,
  sync_id        text,
  updated_at     timestamptz not null default now(),
  primary key (user_id, id)
);

create index if not exists navi_items_due_idx on public.navi_items (user_id, due_at);

-- Seguridad: cada usuario solo ve y toca sus propias filas
alter table public.navi_settings enable row level security;
alter table public.navi_courses  enable row level security;
alter table public.navi_items    enable row level security;

drop policy if exists "own rows" on public.navi_settings;
drop policy if exists "own rows" on public.navi_courses;
drop policy if exists "own rows" on public.navi_items;

create policy "own rows" on public.navi_settings for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own rows" on public.navi_courses for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own rows" on public.navi_items for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- updated_at automático
create or replace function public.navi_touch() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists navi_settings_touch on public.navi_settings;
drop trigger if exists navi_courses_touch  on public.navi_courses;
drop trigger if exists navi_items_touch    on public.navi_items;

create trigger navi_settings_touch before update on public.navi_settings
  for each row execute function public.navi_touch();
create trigger navi_courses_touch before update on public.navi_courses
  for each row execute function public.navi_touch();
create trigger navi_items_touch before update on public.navi_items
  for each row execute function public.navi_touch();

-- Permisos explícitos para usuarios con sesión iniciada
grant select, insert, update, delete on public.navi_settings to authenticated;
grant select, insert, update, delete on public.navi_courses  to authenticated;
grant select, insert, update, delete on public.navi_items    to authenticated;
