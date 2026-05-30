grant select on public.group_members to authenticated;

drop policy if exists "Authenticated users can check own realtime memberships"
  on public.group_members;

create policy "Authenticated users can check own realtime memberships"
on public.group_members
for select
to authenticated
using (user_id = (select auth.uid()));

alter table realtime.messages enable row level security;

drop policy if exists "Sajha users can receive own realtime topics"
  on realtime.messages;

create policy "Sajha users can receive own realtime topics"
on realtime.messages
for select
to authenticated
using (
  realtime.messages.extension = 'broadcast'
  and (
    realtime.topic() = 'user:' || (select auth.uid())::text
    or exists (
      select 1
      from public.group_members gm
      where gm.user_id = (select auth.uid())
        and gm.status in ('active', 'invited')
        and realtime.topic() = 'group:' || gm.group_id::text
    )
  )
);
