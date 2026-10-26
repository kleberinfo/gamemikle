-- GAMEMIKLE v12 — SQL de configuração para Supabase
-- Executar em Dashboard > SQL Editor > New query.
-- Reexecutável: usa CREATE IF NOT EXISTS e políticas com DROP IF EXISTS.
-- A chave secreta nunca deve ser colocada no HTML.

-- 1) Save online por jogador (compatível com as versões anteriores).
create table if not exists public.game_saves (
  user_id uuid primary key references auth.users(id) on delete cascade,
  save_data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.game_saves enable row level security;
revoke all on table public.game_saves from anon, authenticated;
grant select, insert, update on table public.game_saves to authenticated;
drop policy if exists "Players can read their own save" on public.game_saves;
create policy "Players can read their own save" on public.game_saves for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "Players can create their own save" on public.game_saves;
create policy "Players can create their own save" on public.game_saves for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "Players can update their own save" on public.game_saves;
create policy "Players can update their own save" on public.game_saves for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create or replace function public.gamemikle_touch_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at = now(); return new; end;
$$;
drop trigger if exists gamemikle_game_saves_updated_at on public.game_saves;
create trigger gamemikle_game_saves_updated_at before update on public.game_saves for each row execute function public.gamemikle_touch_updated_at();

-- 2) Public profiles for friend discovery and leaderboard.
create table if not exists public.player_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  username text not null,
  power numeric not null default 0,
  rebirths integer not null default 0,
  total_rolls bigint not null default 0,
  updated_at timestamptz not null default now()
);
create unique index if not exists player_profiles_username_lower_uidx on public.player_profiles (lower(username));
alter table public.player_profiles enable row level security;
revoke all on table public.player_profiles from anon, authenticated;
grant select, insert, update on table public.player_profiles to authenticated;
drop policy if exists "Authenticated players can see leaderboard profiles" on public.player_profiles;
create policy "Authenticated players can see leaderboard profiles" on public.player_profiles for select to authenticated using (true);
drop policy if exists "Players can insert their own profile" on public.player_profiles;
create policy "Players can insert their own profile" on public.player_profiles for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "Players can update their own profile" on public.player_profiles;
create policy "Players can update their own profile" on public.player_profiles for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- Auth trigger creates the profile with the username submitted by Gamemikle.
create or replace function public.gamemikle_create_player_profile()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_base text;
  v_username text;
  v_suffix text;
begin
  v_base := coalesce(nullif(new.raw_user_meta_data->>'username',''), split_part(coalesce(new.email,''),'@',1), 'Jogador');
  v_base := left(regexp_replace(v_base, '[^A-Za-z0-9_.-]', '', 'g'), 20);
  if v_base = '' then v_base := 'Jogador'; end if;
  v_username := v_base;
  if exists (select 1 from public.player_profiles p where lower(p.username)=lower(v_username) and p.user_id<>new.id) then
    v_suffix := substr(replace(new.id::text,'-',''),1,6);
    v_username := left(v_base,13)||'-'||v_suffix;
  end if;
  insert into public.player_profiles(user_id, username, power, rebirths, total_rolls, updated_at)
  values(new.id, v_username, 0, 0, 0, now())
  on conflict (user_id) do nothing;
  return new;
end;
$$;
drop trigger if exists gamemikle_profile_after_auth_insert on auth.users;
create trigger gamemikle_profile_after_auth_insert after insert on auth.users for each row execute function public.gamemikle_create_player_profile();

-- Backfill existing accounts. Duplicate display names receive a stable short suffix.
with users as (
  select u.id,
         left(regexp_replace(coalesce(nullif(u.raw_user_meta_data->>'username',''), split_part(coalesce(u.email,''),'@',1), 'Jogador'), '[^A-Za-z0-9_.-]', '', 'g'), 20) as base_name,
         row_number() over (partition by lower(left(regexp_replace(coalesce(nullif(u.raw_user_meta_data->>'username',''), split_part(coalesce(u.email,''),'@',1), 'Jogador'), '[^A-Za-z0-9_.-]', '', 'g'), 20)) order by u.created_at, u.id) as rn
  from auth.users u
)
insert into public.player_profiles(user_id, username)
select id,
       case when coalesce(base_name,'')='' then 'Jogador-'||substr(replace(id::text,'-',''),1,6)
            when rn=1 then base_name
            else left(base_name,13)||'-'||substr(replace(id::text,'-',''),1,6) end
from users
on conflict (user_id) do nothing;

-- 3) Friendships: client must call add_friend_by_username; direct writes are blocked.
create table if not exists public.friendships (
  user_id uuid not null references auth.users(id) on delete cascade,
  friend_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, friend_id),
  constraint friendships_not_self check (user_id <> friend_id)
);
alter table public.friendships enable row level security;
revoke all on table public.friendships from anon, authenticated;
grant select on table public.friendships to authenticated;
drop policy if exists "Players can see their friendships" on public.friendships;
create policy "Players can see their friendships" on public.friendships for select to authenticated using ((select auth.uid())=user_id or (select auth.uid())=friend_id);

create or replace function public.add_friend_by_username(target_username text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_me uuid := auth.uid();
  v_target uuid;
  v_username text;
begin
  if v_me is null then raise exception 'É necessário iniciar sessão.'; end if;
  select user_id, username into v_target, v_username from public.player_profiles where lower(username)=lower(trim(target_username)) limit 1;
  if v_target is null then raise exception 'Jogador não encontrado. Ele precisa criar uma conta primeiro.'; end if;
  if v_target=v_me then raise exception 'Não podes adicionar a tua própria conta.'; end if;
  insert into public.friendships(user_id,friend_id) values(v_me,v_target) on conflict do nothing;
  insert into public.friendships(user_id,friend_id) values(v_target,v_me) on conflict do nothing;
  return jsonb_build_object('ok',true,'username',v_username);
end;
$$;
revoke all on function public.add_friend_by_username(text) from public, anon;
grant execute on function public.add_friend_by_username(text) to authenticated;

-- 3b) Retrieve the current authenticated player's friend usernames.
create or replace function public.list_my_friends()
returns table(username text)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select p.username
  from public.friendships f
  join public.player_profiles p on p.user_id=f.friend_id
  where f.user_id=auth.uid()
  order by lower(p.username);
$$;
revoke all on function public.list_my_friends() from public, anon;
grant execute on function public.list_my_friends() to authenticated;

-- 4) Pet trades. The save arrays are edited atomically on the server when accepted.
create table if not exists public.pet_trade_requests (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users(id) on delete cascade,
  receiver_id uuid not null references auth.users(id) on delete cascade,
  sender_username text not null,
  receiver_username text not null,
  offered_pet_id text not null,
  requested_pet_id text not null,
  status text not null default 'pending' check (status in ('pending','accepted','declined','cancelled')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  constraint pet_trade_not_self check (sender_id <> receiver_id)
);
create index if not exists pet_trade_receiver_pending_idx on public.pet_trade_requests(receiver_id,status,created_at desc);
alter table public.pet_trade_requests enable row level security;
revoke all on table public.pet_trade_requests from anon, authenticated;
grant select on table public.pet_trade_requests to authenticated;
drop policy if exists "Participants can view their trade requests" on public.pet_trade_requests;
create policy "Participants can view their trade requests" on public.pet_trade_requests for select to authenticated using ((select auth.uid())=sender_id or (select auth.uid())=receiver_id);

create or replace function public.request_pet_trade(target_username text, offered_pet_id text, requested_pet_id text)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_me uuid := auth.uid();
  v_target uuid;
  v_sender_name text;
  v_target_name text;
  v_sender_save jsonb;
  v_target_save jsonb;
  v_trade_id uuid;
begin
  if v_me is null then raise exception 'É necessário iniciar sessão.'; end if;
  if nullif(trim(offered_pet_id),'') is null or nullif(trim(requested_pet_id),'') is null then raise exception 'Escolhe os dois pets.'; end if;
  select user_id,username into v_target,v_target_name from public.player_profiles where lower(username)=lower(trim(target_username)) limit 1;
  if v_target is null then raise exception 'O jogador de destino não foi encontrado.'; end if;
  if v_target=v_me then raise exception 'Não podes trocar pets contigo mesmo.'; end if;
  select username into v_sender_name from public.player_profiles where user_id=v_me;
  perform user_id from public.game_saves where user_id in (v_me,v_target) order by user_id for update;
  select save_data into v_sender_save from public.game_saves where user_id=v_me;
  select save_data into v_target_save from public.game_saves where user_id=v_target;
  if v_sender_save is null or not (coalesce(v_sender_save->'owned','[]'::jsonb) @> jsonb_build_array(offered_pet_id)) then raise exception 'Não tens o pet que queres oferecer.'; end if;
  if v_target_save is null or not (coalesce(v_target_save->'owned','[]'::jsonb) @> jsonb_build_array(requested_pet_id)) then raise exception 'O outro jogador não tem o pet pedido.'; end if;
  insert into public.pet_trade_requests(sender_id,receiver_id,sender_username,receiver_username,offered_pet_id,requested_pet_id)
  values(v_me,v_target,coalesce(v_sender_name,'Jogador'),coalesce(v_target_name,'Jogador'),$2,$3)
  returning id into v_trade_id;
  return v_trade_id;
end;
$$;
revoke all on function public.request_pet_trade(text,text,text) from public, anon;
grant execute on function public.request_pet_trade(text,text,text) to authenticated;

create or replace function public.resolve_pet_trade(trade_id uuid, accept_trade boolean)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_trade public.pet_trade_requests%rowtype;
  v_sender_save jsonb;
  v_receiver_save jsonb;
  v_sender_owned jsonb := '[]'::jsonb;
  v_receiver_owned jsonb := '[]'::jsonb;
  v_item jsonb;
  v_removed boolean;
begin
  if auth.uid() is null then raise exception 'É necessário iniciar sessão.'; end if;
  select * into v_trade from public.pet_trade_requests where id=trade_id for update;
  if not found then raise exception 'Pedido de troca não encontrado.'; end if;
  if auth.uid()<>v_trade.receiver_id then raise exception 'Só o destinatário pode responder a esta troca.'; end if;
  if v_trade.status<>'pending' then raise exception 'Este pedido já foi resolvido.'; end if;
  if not accept_trade then
    update public.pet_trade_requests set status='declined',resolved_at=now() where id=trade_id;
    return jsonb_build_object('ok',true,'status','declined','sender_id',v_trade.sender_id,'receiver_id',v_trade.receiver_id);
  end if;
  perform user_id from public.game_saves where user_id in (v_trade.sender_id,v_trade.receiver_id) order by user_id for update;
  select save_data into v_sender_save from public.game_saves where user_id=v_trade.sender_id;
  select save_data into v_receiver_save from public.game_saves where user_id=v_trade.receiver_id;
  if v_sender_save is null or v_receiver_save is null then raise exception 'Falta o save de um dos jogadores.'; end if;
  v_removed:=false;
  for v_item in select value from jsonb_array_elements(coalesce(v_sender_save->'owned','[]'::jsonb)) as a(value) loop
    if not v_removed and v_item #>> '{}' = v_trade.offered_pet_id then v_removed:=true; else v_sender_owned:=v_sender_owned||jsonb_build_array(v_item); end if;
  end loop;
  if not v_removed then raise exception 'O pet oferecido já não está na mochila do remetente.'; end if;
  v_removed:=false;
  for v_item in select value from jsonb_array_elements(coalesce(v_receiver_save->'owned','[]'::jsonb)) as a(value) loop
    if not v_removed and v_item #>> '{}' = v_trade.requested_pet_id then v_removed:=true; else v_receiver_owned:=v_receiver_owned||jsonb_build_array(v_item); end if;
  end loop;
  if not v_removed then raise exception 'O pet pedido já não está na mochila do destinatário.'; end if;
  v_sender_owned:=v_sender_owned||jsonb_build_array(v_trade.requested_pet_id);
  v_receiver_owned:=v_receiver_owned||jsonb_build_array(v_trade.offered_pet_id);
  update public.game_saves set save_data=jsonb_set(coalesce(v_sender_save,'{}'::jsonb),'{owned}',v_sender_owned,true),updated_at=now() where user_id=v_trade.sender_id;
  update public.game_saves set save_data=jsonb_set(coalesce(v_receiver_save,'{}'::jsonb),'{owned}',v_receiver_owned,true),updated_at=now() where user_id=v_trade.receiver_id;
  update public.pet_trade_requests set status='accepted',resolved_at=now() where id=trade_id;
  return jsonb_build_object('ok',true,'status','accepted','sender_id',v_trade.sender_id,'receiver_id',v_trade.receiver_id);
end;
$$;
revoke all on function public.resolve_pet_trade(uuid,boolean) from public, anon;
grant execute on function public.resolve_pet_trade(uuid,boolean) to authenticated;

-- Nota: a loja de dinheiro real e sessões multiplayer autoritativas precisam de serviço de servidor/checkout.
-- Este SQL não configura nem cobra pagamentos reais.