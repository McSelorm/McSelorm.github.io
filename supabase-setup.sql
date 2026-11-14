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

-- ID card upload (private file path, never shown publicly)
alter table public.businesses add column if not exists id_card_path text;

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
    if new.id_card_path is not null and split_part(new.id_card_path, '/', 1) <> auth.uid()::text then
      raise exception 'ID card file must be your own';
    end if;
  elsif not public.is_admin() then
    new.id_card_path := old.id_card_path;
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

-- 6. Private, locked folder for ID cards.
--    Each member can only add files in their own folder.
--    Only that member and Selorm can open them. Max 5 MB, photos or PDF.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('id-cards', 'id-cards', false, 5242880, array['image/jpeg','image/png','image/webp','application/pdf'])
on conflict (id) do update
  set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "id cards: upload own"        on storage.objects;
drop policy if exists "id cards: read own or admin" on storage.objects;
drop policy if exists "id cards: delete own or admin" on storage.objects;

create policy "id cards: upload own" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'id-cards' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "id cards: read own or admin" on storage.objects
  for select to authenticated
  using (bucket_id = 'id-cards' and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));

create policy "id cards: delete own or admin" on storage.objects
  for delete to authenticated
  using (bucket_id = 'id-cards' and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));


-- 7. Activity log for Selorm's dashboard.
--    Anyone visiting can ADD a line (page visited, device, where they came from).
--    Only Selorm can READ it. No IP addresses are saved here.
create table if not exists public.activity (
  id          bigint generated always as identity primary key,
  created_at  timestamptz not null default now(),
  visitor     text check (char_length(visitor) <= 40),
  user_id     uuid,
  event       text not null check (event in ('visit','signup','login','logout','post_business','report')),
  page        text check (char_length(page) <= 100),
  detail      text check (char_length(detail) <= 200),
  referrer    text check (char_length(referrer) <= 100),
  device      text check (char_length(device) <= 20)
);
alter table public.activity enable row level security;

create or replace function public.stamp_activity() returns trigger
language plpgsql as $$
begin
  new.user_id := auth.uid();
  new.created_at := now();
  return new;
end $$;
drop trigger if exists stamp_activity on public.activity;
create trigger stamp_activity before insert on public.activity
  for each row execute function public.stamp_activity();

drop policy if exists "activity: anyone adds"  on public.activity;
drop policy if exists "activity: admin reads"  on public.activity;
drop policy if exists "activity: admin deletes" on public.activity;
create policy "activity: anyone adds"   on public.activity for insert to anon, authenticated with check (true);
create policy "activity: admin reads"   on public.activity for select to authenticated using (public.is_admin());
create policy "activity: admin deletes" on public.activity for delete to authenticated using (public.is_admin());
grant insert on public.activity to anon, authenticated;
grant select, delete on public.activity to authenticated;

-- 8. Reports: anyone can report a problem or scam. Only Selorm reads them.
create table if not exists public.reports (
  id           bigint generated always as identity primary key,
  created_at   timestamptz not null default now(),
  user_id      uuid default auth.uid(),
  business_id  uuid,
  business_name text check (char_length(business_name) <= 80),
  name         text check (char_length(name) <= 80),
  contact      text check (char_length(contact) <= 120),
  message      text not null check (char_length(message) between 5 and 1500),
  status       text not null default 'open' check (status in ('open','solved'))
);
alter table public.reports enable row level security;

drop policy if exists "reports: anyone adds"     on public.reports;
drop policy if exists "reports: admin reads"     on public.reports;
drop policy if exists "reports: admin updates"   on public.reports;
drop policy if exists "reports: admin deletes"   on public.reports;
create policy "reports: anyone adds"   on public.reports for insert to anon, authenticated with check (status = 'open');
create policy "reports: admin reads"   on public.reports for select to authenticated using (public.is_admin());
create policy "reports: admin updates" on public.reports for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "reports: admin deletes" on public.reports for delete to authenticated using (public.is_admin());
grant insert on public.reports to anon, authenticated;
grant select, update, delete on public.reports to authenticated;

-- Done! You should see "Success. No rows returned".
