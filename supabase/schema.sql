-- Supabase SQL Editor에서 한 번만 실행하면 되는 스키마.
-- 방문자(visitor) 1명당 1행. 같은 브라우저는 localStorage의 visitor_id로 항상 같은 행을 가리킴.

create table if not exists public.visitors (
  visitor_id text primary key,
  session_id text not null,
  visited_at timestamptz not null default now(),
  saved_account boolean not null default false,
  save_count integer not null default 0,
  version text not null default 'v1'
);

alter table public.visitors enable row level security;

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

-- anon이 테이블을 직접 UPDATE할 때는 session_id 컬럼만 건드릴 수 있도록 제한.
-- saved_account/save_count는 아래 increment_save_count 함수를 통해서만 바뀜.
revoke update on public.visitors from anon;
grant update (session_id) on public.visitors to anon;

-- 계정을 저장할 때마다 호출: saved_account를 true로, save_count를 1 증가.
create or replace function public.increment_save_count(p_visitor_id text)
returns void
language sql
security definer
set search_path = public
as $$
  update public.visitors
  set saved_account = true,
      save_count = save_count + 1
  where visitor_id = p_visitor_id;
$$;

grant execute on function public.increment_save_count(text) to anon;
