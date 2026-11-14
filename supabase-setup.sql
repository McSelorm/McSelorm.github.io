-- =============================================================
-- Grow With Selorm: database setup
-- Paste ALL of this into Supabase > SQL Editor > New query > Run.
-- It is safe to run again if you need to.
-- =============================================================

-- 1. The table that holds every business people post
create table if not exists public.businesses (
  id               uuid primary key default gen_random_uuid(),
  owner            uuid not null default auth.uid() references auth.users(id) on delete cascade,
  owner_email      text,
  owner_name       text not null check (char_length(owner_name) between 1 and 80),
  name             text not null check (char_length(name) between 1 and 80),
  type             text not null,
  location         text not null check (char_length(location) <= 80),
  stage            text not null,
  monthly_sales    numeric not null default 0 check (monthly_sales >= 0),
  about            text not null check (char_length(about) <= 1500),
  amount           numeric not null check (amount > 0),
  use_of_money     text not null check (char_length(use_of_money) <= 200),
  investor_gets    text not null check (char_length(investor_gets) <= 800),
  phone            text not null check (char_length(phone) <= 30),
  show_phone       boolean not null default false,
  ghana_card_name  text not null check (char_length(ghana_card_name) <= 100),
  agree_id_check   boolean not null default false check (agree_id_check),
  status           text not null default 'pending' check (status in ('pending','approved','rejected')),
  id_checked       boolean not null default false,
  created_at       timestamptz not null default now()
);

alter table public.businesses enable row level security;

-- 2. Who is the admin? Only Selorm's email.
create or replace function public.is_admin() returns boolean
language sql stable as $$
  select coalesce(auth.jwt() ->> 'email', '') = 'selormmc85@gmail.com'
$$;

-- 3. Safety rules (Row Level Security)
drop policy if exists "read own or admin"   on public.businesses;
drop policy if exists "insert own"          on public.businesses;
drop policy if exists "update own or admin" on public.businesses;
drop policy if exists "delete own or admin" on public.businesses;

create policy "read own or admin" on public.businesses
  for select to authenticated using (owner = auth.uid() or public.is_admin());

create policy "insert own" on public.businesses
  for insert to authenticated with check (owner = auth.uid());

create policy "update own or admin" on public.businesses
  for update to authenticated
  using (owner = auth.uid() or public.is_admin())
  with check (owner = auth.uid() or public.is_admin());

create policy "delete own or admin" on public.businesses
  for delete to authenticated using (owner = auth.uid() or public.is_admin());

revoke all on public.businesses from anon;
grant select, insert, update, delete on public.businesses to authenticated;

-- 4. Members cannot approve themselves or give themselves the ID badge
create or replace function public.protect_business() returns trigger
language plpgsql as $$
begin
  if tg_op = 'INSERT' then
    new.owner := auth.uid();
    new.owner_email := auth.jwt() ->> 'email';
    new.status := 'pending';
    new.id_checked := false;
    new.created_at := now();
  elsif not public.is_admin() then
    new.owner := old.owner;
    new.owner_email := old.owner_email;
    new.created_at := old.created_at;
    new.id_checked := old.id_checked;
    new.status := 'pending';   -- any change by the owner is checked again
  end if;
  return new;
end $$;

drop trigger if exists protect_business on public.businesses;
create trigger protect_business before insert or update on public.businesses
  for each row execute function public.protect_business();

-- 5. What the public can see: approved businesses only,
--    phone only if the owner said yes, never the Ghana Card name or email.
drop view if exists public.approved_businesses;
create view public.approved_businesses as
  select id, name, type, location, stage, monthly_sales, about, amount,
         use_of_money, investor_gets, owner_name,
         case when show_phone then phone else null end as phone,
         id_checked, created_at
  from public.businesses
  where status = 'approved';

grant select on public.approved_businesses to anon, authenticated;

-- Done! You should see "Success. No rows returned".
