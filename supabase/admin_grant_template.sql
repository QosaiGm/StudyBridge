-- Run this privately in Supabase SQL Editor after the target Auth email is verified.
-- Replace the placeholder with the admin's verified email, then run this query.
insert into public.app_admins (user_id)
select id
from auth.users
where lower(email) = lower('YOUR_CONFIRMED_ADMIN_EMAIL')
  and email_confirmed_at is not null
on conflict (user_id) do nothing;
