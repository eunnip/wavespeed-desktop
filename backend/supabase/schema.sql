create table if not exists public.ios_users (
  id text primary key,
  apple_subject text not null unique,
  email text,
  display_name text,
  deleted_at timestamptz,
  created_at timestamptz not null,
  updated_at timestamptz not null
);

create table if not exists public.ios_refresh_sessions (
  token_hash text primary key,
  token_hint text,
  user_id text not null references public.ios_users(id) on delete cascade,
  expires_at timestamptz not null,
  created_at timestamptz not null,
  revoked_at timestamptz
);

create index if not exists ios_refresh_sessions_user_id_idx on public.ios_refresh_sessions (user_id);
create index if not exists ios_refresh_sessions_expires_at_idx on public.ios_refresh_sessions (expires_at);

create table if not exists public.ios_access_sessions (
  token_hash text primary key,
  token_hint text,
  user_id text not null references public.ios_users(id) on delete cascade,
  refresh_token_hash text,
  expires_at timestamptz not null,
  created_at timestamptz not null,
  revoked_at timestamptz
);

create index if not exists ios_access_sessions_user_id_idx on public.ios_access_sessions (user_id);
create index if not exists ios_access_sessions_expires_at_idx on public.ios_access_sessions (expires_at);

create table if not exists public.ios_purchases (
  id text primary key,
  user_id text not null references public.ios_users(id) on delete cascade,
  product_id text not null,
  transaction_id text not null unique,
  original_transaction_id text,
  app_account_token uuid,
  signed_transaction_info text,
  expires_at timestamptz not null,
  source text not null check (source in ('sync', 'restore')),
  environment text,
  created_at timestamptz not null,
  revoked_at timestamptz
);

create index if not exists ios_purchases_user_id_idx on public.ios_purchases (user_id);
create index if not exists ios_purchases_original_transaction_id_idx on public.ios_purchases (original_transaction_id);
create index if not exists ios_purchases_expires_at_idx on public.ios_purchases (expires_at desc);

create table if not exists public.ios_uploads (
  id text primary key,
  user_id text not null references public.ios_users(id) on delete cascade,
  filename text not null,
  mime_type text not null,
  storage_key text not null,
  created_at timestamptz not null
);

create index if not exists ios_uploads_user_id_idx on public.ios_uploads (user_id);

create table if not exists public.ios_jobs (
  id text primary key,
  user_id text not null references public.ios_users(id) on delete cascade,
  model_id text not null,
  model_name text,
  prompt text,
  negative_prompt text,
  image_url text,
  status text not null check (status in ('queued', 'running', 'completed', 'failed', 'canceled')),
  error_message text,
  outputs jsonb not null default '[]'::jsonb,
  created_at timestamptz not null,
  updated_at timestamptz not null
);

create index if not exists ios_jobs_user_id_created_at_idx on public.ios_jobs (user_id, created_at desc);
