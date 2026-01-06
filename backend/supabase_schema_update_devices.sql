
-- USER DEVICES (Push Notification Tokens)
create table public.user_devices (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  device_token text not null,
  platform text check (platform in ('ios', 'android', 'web')),
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(user_id, device_token)
);

-- RLS: User Devices
alter table public.user_devices enable row level security;
create policy "Users can view own devices" on public.user_devices
  for select using (auth.uid() = user_id);
create policy "Users can register own devices" on public.user_devices
  for insert with check (auth.uid() = user_id);
create policy "Users can delete own devices" on public.user_devices
  for delete using (auth.uid() = user_id);
