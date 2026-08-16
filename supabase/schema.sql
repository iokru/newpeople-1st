-- Supabase SQL Editor에서 실행하는 스키마 (재실행해도 안전함).
-- (visitor_id, version) 조합이 1행. 같은 브라우저(visitor_id)라도
-- APP_VERSION이 바뀌면 새 행이 생겨서 그 버전에서는 새 방문자로 집계됨.

create table if not exists public.visitors (
  visitor_id text not null,
  session_id text not null,
  visited_at timestamptz not null default now(),
  saved_account boolean not null default false,
  save_count integer not null default 0,
  version text not null default 'v1',
  primary key (visitor_id, version)
);

-- 예전 스키마(visitor_id 단독 PK)로 이미 만들어져 있었다면
-- (visitor_id, version) 조합 PK로 교체. 새로 만든 테이블에서는 그냥 통과됨.
alter table public.visitors drop constraint if exists visitors_pkey;
alter table public.visitors add constraint visitors_pkey primary key (visitor_id, version);

alter table public.visitors enable row level security;

-- 재실행해도 안전하도록 기존 정책을 먼저 제거
drop policy if exists "anon can insert visitor" on public.visitors;
drop policy if exists "anon can update visitor" on public.visitors;

-- 최초 방문 시 새 행을 만들 수 있어야 함
create policy "anon can insert visitor" on public.visitors
  for insert
  to anon
  with check (true);

-- 재방문 시 session_id만 갱신할 수 있어야 함
create policy "anon can update visitor" on public.visitors
  for update
  to anon
  using (true)
  with check (true);

grant insert on public.visitors to anon;

-- anon이 테이블을 직접 UPDATE할 때는 session_id 컬럼만 건드릴 수 있도록 제한.
-- saved_account/save_count는 아래 increment_save_count 함수를 통해서만 바뀜.
revoke update on public.visitors from anon;
grant update (session_id) on public.visitors to anon;

-- 계정을 저장할 때마다 호출: saved_account를 true로, save_count를 1 증가.
-- visitor_id만으로는 버전별 행을 구분 못 하므로 version도 같이 받음.
drop function if exists public.increment_save_count(text);

create or replace function public.increment_save_count(p_visitor_id text, p_version text)
returns void
language sql
security definer
set search_path = public
as $$
  update public.visitors
  set saved_account = true,
      save_count = save_count + 1
  where visitor_id = p_visitor_id
    and version = p_version;
$$;

grant execute on function public.increment_save_count(text, text) to anon;
