-- Enable Vector extension for AI embeddings
create extension if not exists vector;

-- PROFILES (Public user data)
create table public.profiles (
  id uuid references auth.users on delete cascade not null primary key,
  username text unique,
  full_name text,
  avatar_url text,
  fcm_token text, -- For Push Notifications
  created_at timestamptz default now()
);

-- RLS: Profiles are viewable by everyone, editable only by self
alter table public.profiles enable row level security;
create policy "Public profiles are viewable by everyone" on public.profiles
  for select using (true);
create policy "Users can insert their own profile" on public.profiles
  for insert with check (auth.uid() = id);
create policy "Users can update own profile" on public.profiles
  for update using (auth.uid() = id);

-- RECIPES
create table public.recipes (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  title text not null,
  description text,
  video_url text,
  ingredients jsonb, -- Structured data: [{name: "flour", amount: "1", unit: "cup"}]
  instructions jsonb, -- Array of strings
  embedding vector(768), -- Gemini Embedding
  thumbnail_url text, -- Permanent URL from Supabase Storage
  chefs_note text, -- AI chef's tip for this recipe
  is_favorite boolean default false,
  parent_recipe_id uuid references public.recipes(id), -- For remix attribution
  source_prompt text, -- AI prompt used to generate this recipe
  created_at timestamptz default now()
);

-- RLS: Recipes are private to their owner
alter table public.recipes enable row level security;
create policy "Users can view their own recipes" on public.recipes
  for select using (auth.uid() = user_id);
create policy "Users can insert their own recipes" on public.recipes
  for insert with check (auth.uid() = user_id);
create policy "Users can update own recipes" on public.recipes
  for update using (auth.uid() = user_id);
create policy "Users can delete own recipes" on public.recipes
  for delete using (auth.uid() = user_id);

-- FOLLOWS
create table public.follows (
  follower_id uuid references public.profiles(id) on delete cascade not null,
  following_id uuid references public.profiles(id) on delete cascade not null,
  created_at timestamptz default now(),
  primary key (follower_id, following_id)
);

-- RLS: Follows
alter table public.follows enable row level security;
create policy "Follows are viewable by everyone" on public.follows
  for select using (true);
create policy "Users can follow others" on public.follows
  for insert with check (auth.uid() = follower_id);
create policy "Users can unfollow" on public.follows
  for delete using (auth.uid() = follower_id);

-- TRIGGER: Create profile on signup
-- This automatically creates a row in public.profiles when a user signs up via Auth
create function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name, avatar_url)
  values (new.id, new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'avatar_url');
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
