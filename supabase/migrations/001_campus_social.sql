-- Inside LASU social beta. Run ONCE in the NEW Inside LASU project's SQL Editor.
-- Creates only the dedicated inside_lasu schema and two named public RPC functions.
begin;
create schema if not exists inside_lasu;
revoke all on schema inside_lasu from public, anon, authenticated;
create table if not exists inside_lasu.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 username text unique not null check (username ~ '^[a-z][a-z0-9_]{2,23}$'),
 created timestamptz not null default now()
);
create table if not exists inside_lasu.messages (
 id bigint generated always as identity primary key,
 sender uuid not null references inside_lasu.profiles(id) on delete cascade,
 recipient uuid not null references inside_lasu.profiles(id) on delete cascade,
 body text not null check(length(btrim(body)) between 1 and 1000),
 created timestamptz not null default now(), check(sender<>recipient)
);
create index if not exists lasu_message_pair on inside_lasu.messages(recipient,sender,id desc);
create table if not exists inside_lasu.relationships (
 id bigint generated always as identity primary key,
 sender uuid not null references inside_lasu.profiles(id) on delete cascade,
 recipient uuid not null references inside_lasu.profiles(id) on delete cascade,
 kind text not null check(kind in ('Friends','Dating','BFFs','Gs','Reading partners','Project teammates','Roommates','Mentor buddies')),
 status text not null default 'pending' check(status in ('pending','accepted','declined','ended')),
 created timestamptz not null default now(), check(sender<>recipient)
);
create unique index if not exists lasu_live_relation on inside_lasu.relationships(least(sender,recipient),greatest(sender,recipient),kind) where status in ('pending','accepted');
create table if not exists inside_lasu.blocks (
 owner uuid references inside_lasu.profiles(id) on delete cascade,
 target uuid references inside_lasu.profiles(id) on delete cascade,
 primary key(owner,target),check(owner<>target)
);
create table if not exists inside_lasu.presence (
 user_id uuid primary key references inside_lasu.profiles(id) on delete cascade,
 location text not null check(length(location) between 1 and 160),
 x double precision not null,y double precision not null,z double precision not null,yaw double precision not null,
 updated timestamptz not null default now(),
 check(abs(x)<=5000 and abs(y)<=5000 and abs(z)<=5000 and abs(yaw)<=5000)
);
create index if not exists lasu_presence_location on inside_lasu.presence(location,updated);
create table if not exists inside_lasu.reports (
 id bigint generated always as identity primary key,
 owner uuid references inside_lasu.profiles(id) on delete cascade,
 target uuid references inside_lasu.profiles(id) on delete cascade,
 reason text not null check(length(btrim(reason)) between 5 and 500),
 created timestamptz not null default now()
);
-- Deny direct table access, including when the public project key is visible.
-- All access goes through the checked, narrowly scoped RPC below.
alter table inside_lasu.profiles enable row level security;
alter table inside_lasu.messages enable row level security;
alter table inside_lasu.relationships enable row level security;
alter table inside_lasu.blocks enable row level security;
alter table inside_lasu.presence enable row level security;
alter table inside_lasu.reports enable row level security;
revoke all on all tables in schema inside_lasu from public,anon,authenticated;
revoke all on all sequences in schema inside_lasu from public,anon,authenticated;

create or replace function public.lasu_health() returns jsonb language sql
security definer set search_path='' as $$
 select jsonb_build_object('service','Inside LASU Supabase social','version',1);
$$;
revoke all on function public.lasu_health() from public;
grant execute on function public.lasu_health() to anon,authenticated;

create or replace function public.lasu_api(route text, payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 me uuid := auth.uid(); other uuid; name_value text; own_name text;
 result jsonb; item inside_lasu.relationships%rowtype; message_text text;
 posx double precision; posy double precision; posz double precision; heading double precision;
 location_value text; kind_value text; status_value text;
begin
 if me is null or not exists(select 1 from auth.users where id=me) then
  return jsonb_build_object('error','Sign in to your social account');
 end if;
 if jsonb_typeof(payload)<>'object' or octet_length(payload::text)>8192 then
  return jsonb_build_object('error','Invalid request');
 end if;
 if route='/profile' then
  select username into own_name from inside_lasu.profiles where id=me;
  if own_name is null then
   name_value := lower(btrim(coalesce(payload->>'username','')));
   if name_value !~ '^[a-z][a-z0-9_]{2,23}$' then
    return jsonb_build_object('error','Choose a username: 3–24 letters, numbers or underscores, starting with a letter');
   end if;
   insert into inside_lasu.profiles(id,username) values(me,name_value);
   own_name := name_value;
  end if;
  return jsonb_build_object('username',own_name);
 end if;
 -- Serialise each player's actions so rate checks cannot race writes.
 select username into own_name from inside_lasu.profiles where id=me for update;
 if own_name is null then return jsonb_build_object('error','Finish choosing your username'); end if;
 if route='/account/delete' then
  delete from auth.users where id=me;
  return jsonb_build_object('ok',true);
 elsif route='/users' then
  name_value := lower(btrim(coalesce(payload->>'q','')));
  if name_value !~ '^[a-z0-9_]{2,24}$' then return jsonb_build_object('error','Search with at least two username characters'); end if;
  select coalesce(jsonb_agg(jsonb_build_object('username',p.username)),'[]'::jsonb) into result
  from (select id,username from inside_lasu.profiles where id<>me and strpos(username,name_value)>0 order by username limit 20) p
  where not exists(select 1 from inside_lasu.blocks b where (b.owner=me and b.target=p.id) or (b.owner=p.id and b.target=me));
  return jsonb_build_object('users',result);
 elsif route='/blocks' then
  select coalesce(jsonb_agg(jsonb_build_object('username',p.username)),'[]'::jsonb) into result from inside_lasu.blocks b join inside_lasu.profiles p on p.id=b.target where b.owner=me;
  return jsonb_build_object('users',result);
 elsif route='/presence' then
  location_value := btrim(coalesce(payload->>'location',''));
  if length(location_value) not between 1 and 160 then return jsonb_build_object('error','Invalid location'); end if;
  if location_value like 'private:%' then
   delete from inside_lasu.presence where user_id=me;
   return jsonb_build_object('peers','[]'::jsonb);
  end if;
  posx:=coalesce((payload->>'x')::double precision,0);posy:=coalesce((payload->>'y')::double precision,0);
  posz:=coalesce((payload->>'z')::double precision,0);heading:=coalesce((payload->>'yaw')::double precision,0);
  if not(abs(posx)<=5000 and abs(posy)<=5000 and abs(posz)<=5000 and abs(heading)<=5000) then return jsonb_build_object('error','Invalid position'); end if;
  insert into inside_lasu.presence values(me,location_value,posx,posy,posz,heading,now())
   on conflict(user_id) do update set location=excluded.location,x=excluded.x,y=excluded.y,z=excluded.z,yaw=excluded.yaw,updated=now();
  -- Bound stale storage even when browsers disappear without signing out.
  delete from inside_lasu.presence where updated<now()-interval '5 minutes';
  select coalesce(jsonb_agg(jsonb_build_object('username',p.username,'x',p.x,'y',p.y,'z',p.z,'yaw',p.yaw)),'[]'::jsonb) into result
  from (select n.*,u.username from inside_lasu.presence n join inside_lasu.profiles u on u.id=n.user_id where n.user_id<>me and n.location=location_value and n.updated>now()-interval '25 seconds'
   and not exists(select 1 from inside_lasu.blocks b where (b.owner=me and b.target=n.user_id) or (b.owner=n.user_id and b.target=me)) limit 50) p;
  return jsonb_build_object('peers',result);
 elsif route='/inbox' then
  select coalesce(jsonb_agg(jsonb_build_object('username',p.username)),'[]'::jsonb) into result from
   (select distinct u.id,u.username from inside_lasu.profiles u join inside_lasu.messages m on (m.sender=u.id and m.recipient=me) or (m.recipient=u.id and m.sender=me)
    where not exists(select 1 from inside_lasu.blocks b where (b.owner=me and b.target=u.id) or (b.owner=u.id and b.target=me)) order by u.username limit 100) p;
  return jsonb_build_object('username',own_name,'threads',result,'relationships',coalesce((
   select jsonb_agg(v) from (select r.id,r.kind,r.status,a.username sender_name,b.username recipient_name from inside_lasu.relationships r join inside_lasu.profiles a on a.id=r.sender join inside_lasu.profiles b on b.id=r.recipient
    where (r.sender=me or r.recipient=me) and r.status in ('pending','accepted') and not exists(select 1 from inside_lasu.blocks x where (x.owner=r.sender and x.target=r.recipient) or (x.owner=r.recipient and x.target=r.sender)) order by r.id desc limit 100) v),'[]'::jsonb));
 elsif route='/relationship/respond' then
  select * into item from inside_lasu.relationships where id=(payload->>'id')::bigint for update;
  status_value:=payload->>'status';
  if item.id is null or me not in (item.sender,item.recipient) then return jsonb_build_object('error','Request not found'); end if;
  if status_value not in ('accepted','declined','ended') or status_value is null then return jsonb_build_object('error','Invalid response'); end if;
  if status_value<>'ended' and (me<>item.recipient or item.status<>'pending') then return jsonb_build_object('error','Only the recipient can accept a pending invitation'); end if;
  if exists(select 1 from inside_lasu.blocks where (owner=item.sender and target=item.recipient) or (owner=item.recipient and target=item.sender)) then return jsonb_build_object('error','Contact unavailable'); end if;
  update inside_lasu.relationships set status=status_value where id=item.id;
  return jsonb_build_object('ok',true);
 end if;
 select id into other from inside_lasu.profiles where username=lower(coalesce(payload->>'to',''));
 if other is null or other=me then return jsonb_build_object('error','Player not found'); end if;
 if route='/block' then
  insert into inside_lasu.blocks values(me,other) on conflict do nothing;
  update inside_lasu.relationships set status='ended' where (sender=me and recipient=other) or (sender=other and recipient=me);
  return jsonb_build_object('ok',true);
 elsif route='/unblock' then
  delete from inside_lasu.blocks where owner=me and target=other;
  return jsonb_build_object('ok',true);
 elsif route='/report' then
  message_text:=btrim(coalesce(payload->>'reason',''));
  if length(message_text) not between 5 and 500 then return jsonb_build_object('error','Explain the issue in 5–500 characters'); end if;
  if (select count(*) from inside_lasu.reports where owner=me and created>now()-interval '1 hour')>=10 then return jsonb_build_object('error','Report limit reached'); end if;
  insert into inside_lasu.reports(owner,target,reason) values(me,other,message_text);
  return jsonb_build_object('ok',true);
 end if;
 if exists(select 1 from inside_lasu.blocks where (owner=me and target=other) or (owner=other and target=me)) then return jsonb_build_object('error','Contact unavailable'); end if;
 if route='/messages/read' then
  select coalesce(jsonb_agg(v order by v.id),'[]'::jsonb) into result from
   (select m.id,u.username sender,m.body,extract(epoch from m.created) created from inside_lasu.messages m join inside_lasu.profiles u on u.id=m.sender
    where (m.sender=me and m.recipient=other) or (m.sender=other and m.recipient=me) order by m.id desc limit 80) v;
  return jsonb_build_object('messages',result);
 elsif route='/messages/send' then
  message_text:=btrim(coalesce(payload->>'body',''));
  if length(message_text) not between 1 and 1000 then return jsonb_build_object('error','Messages must contain 1–1000 characters'); end if;
  if (select count(*) from inside_lasu.messages where sender=me and created>now()-interval '1 minute')>=20 then return jsonb_build_object('error','Message limit reached; wait a minute'); end if;
  insert into inside_lasu.messages(sender,recipient,body) values(me,other,message_text);
  return jsonb_build_object('ok',true);
 elsif route='/relationship' then
  kind_value:=payload->>'kind';
  if kind_value is null or kind_value not in ('Friends','Dating','BFFs','Gs','Reading partners','Project teammates','Roommates','Mentor buddies') then return jsonb_build_object('error','Unknown relationship type'); end if;
  if (select count(*) from inside_lasu.relationships where sender=me and created>now()-interval '1 hour')>=20 then return jsonb_build_object('error','Invitation limit reached'); end if;
  insert into inside_lasu.relationships(sender,recipient,kind) values(me,other,kind_value);
  return jsonb_build_object('ok',true);
 end if;
 return jsonb_build_object('error','Unknown action');
exception
 when unique_violation then return jsonb_build_object('error','Username unavailable or invitation already exists');
 when check_violation or invalid_text_representation or numeric_value_out_of_range or foreign_key_violation then return jsonb_build_object('error','Invalid request');
end;
$$;
revoke all on function public.lasu_api(text,jsonb) from public,anon;
grant execute on function public.lasu_api(text,jsonb) to authenticated;
notify pgrst, 'reload schema';
commit;
