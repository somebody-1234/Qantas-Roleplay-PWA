-- Qantas Roleplay ONLY: demo credentials are not real travel documents.
-- In Supabase SQL Editor, run this entire file.
create table if not exists public.roleplay_credentials (
  code text primary key,
  kind text not null check (kind in ('pass','invite')),
  status text not null default 'valid' check (status in ('valid','used','expired','revoked')),
  payload jsonb not null,
  created_at timestamptz not null default now(),
  used_at timestamptz
);
alter table public.roleplay_credentials enable row level security;
-- Public demo policy: anyone with the site can read/create/update demo records.
-- This is convenient for roleplay but NOT secure against tampering. Never use real personal data.
drop policy if exists "demo read credentials" on public.roleplay_credentials;
drop policy if exists "demo create credentials" on public.roleplay_credentials;
drop policy if exists "demo update credentials" on public.roleplay_credentials;
create policy "demo read credentials" on public.roleplay_credentials for select to anon, authenticated using (true);
create policy "demo create credentials" on public.roleplay_credentials for insert to anon, authenticated with check (true);
create policy "demo update credentials" on public.roleplay_credentials for update to anon, authenticated using (true) with check (true);
-- Atomic redeem: concurrent scanners cannot both redeem the same credential.
create or replace function public.redeem_roleplay_credential(p_code text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r public.roleplay_credentials%rowtype;
begin
  select * into r from public.roleplay_credentials where code = upper(trim(p_code)) for update;
  if not found then return jsonb_build_object('ok',false,'reason','not_found'); end if;
  if r.status <> 'valid' then return jsonb_build_object('ok',false,'reason',r.status,'record',to_jsonb(r)); end if;
  if coalesce(r.payload->>'date','9999-12-31') < to_char(current_date,'YYYY-MM-DD') then
    update public.roleplay_credentials set status='expired' where code=r.code;
    return jsonb_build_object('ok',false,'reason','expired');
  end if;
  update public.roleplay_credentials set status='used', used_at=now() where code=r.code returning * into r;
  return jsonb_build_object('ok',true,'record',to_jsonb(r));
end; $$;
revoke all on function public.redeem_roleplay_credential(text) from public;
grant execute on function public.redeem_roleplay_credential(text) to anon, authenticated;
