-- Supabase Datenbank für Werkzeugverwaltung
create extension if not exists "pgcrypto";

create table if not exists public.tools (
 id uuid primary key default gen_random_uuid(),
 tool_number text unique not null,
 name text not null,
 category text,
 model text,
 serial_number text,
 location text,
 status text not null default 'available' check (status in ('available','maintenance')),
 created_at timestamptz not null default now()
);

create table if not exists public.loans (
 id uuid primary key default gen_random_uuid(),
 tool_id uuid not null references public.tools(id) on delete restrict,
 borrower_email text not null,
 department text,
 checked_out_by uuid references auth.users(id),
 checked_out_at timestamptz not null default now(),
 returned_by uuid references auth.users(id),
 returned_at timestamptz
);

alter table public.tools enable row level security;
alter table public.loans enable row level security;

-- Alle angemeldeten Mitarbeiter dürfen Werkzeuge sehen und verwalten.
create policy "authenticated read tools" on public.tools for select to authenticated using (true);
create policy "authenticated insert tools" on public.tools for insert to authenticated with check (true);
create policy "authenticated update tools" on public.tools for update to authenticated using (true) with check (true);
create policy "authenticated delete tools" on public.tools for delete to authenticated using (true);

create policy "authenticated read loans" on public.loans for select to authenticated using (true);
create policy "authenticated insert loans" on public.loans for insert to authenticated with check (true);
create policy "authenticated update loans" on public.loans for update to authenticated using (true) with check (true);

-- Optional: eindeutige offene Ausgabe pro Werkzeug.
create unique index if not exists one_open_loan_per_tool
on public.loans(tool_id) where returned_at is null;
