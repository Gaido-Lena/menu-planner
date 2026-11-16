-- Планировщик меню: три документа (блюда, план, отметки) и доступ по списку почт.

create schema if not exists private;

-- Кому открыт планировщик. Добавлять почты строчными буквами:
--   insert into private.allowed_emails(email) values ('name@example.com');
create table private.allowed_emails (
  email text primary key check (email = lower(email)),
  added_at timestamptz not null default now()
);

create or replace function private.is_member()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from private.allowed_emails a
    where a.email = lower(coalesce((select auth.jwt()) ->> 'email', ''))
  );
$$;

revoke all on schema private from public, anon;
grant usage on schema private to authenticated;
revoke all on function private.is_member() from public, anon;
grant execute on function private.is_member() to authenticated;

create table public.planner_docs (
  key text primary key check (key in ('dishes','plan','checks')),
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.planner_docs enable row level security;

create policy "members read" on public.planner_docs
  for select to authenticated using ((select private.is_member()));
create policy "members insert" on public.planner_docs
  for insert to authenticated with check ((select private.is_member()));
create policy "members update" on public.planner_docs
  for update to authenticated using ((select private.is_member())) with check ((select private.is_member()));

revoke all on public.planner_docs from anon;

create or replace function public.planner_docs_touch()
returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at = now(); return new; end $$;
revoke all on function public.planner_docs_touch() from public, anon, authenticated;

create trigger planner_docs_touch before update on public.planner_docs
  for each row execute function public.planner_docs_touch();

alter publication supabase_realtime add table public.planner_docs;
