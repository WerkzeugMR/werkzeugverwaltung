-- Werkzeugverwaltung v2
create extension if not exists "pgcrypto";

create table if not exists public.employees (
 id uuid primary key default gen_random_uuid(),
 employee_no char(4) unique not null check (employee_no ~ '^[0-9]{4}$'),
 name text not null,
 email text unique not null,
 role text not null default 'employee' check (role in ('employee','host')),
 active boolean not null default true,
 created_at timestamptz not null default now()
);

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
 employee_id uuid references public.employees(id) on delete restrict,
 borrower_email text not null,
 employee_no char(4),
 department text,
 checkout_note text,
 return_note text,
 checked_out_by uuid references auth.users(id),
 checked_out_at timestamptz not null default now(),
 returned_by uuid references auth.users(id),
 returned_at timestamptz
);

-- Safe migrations for existing installations.
alter table public.loans add column if not exists employee_id uuid references public.employees(id) on delete restrict;
alter table public.loans add column if not exists employee_no char(4);
alter table public.loans add column if not exists checkout_note text;
alter table public.loans add column if not exists return_note text;
alter table public.tools drop constraint if exists tools_status_check;
alter table public.tools add constraint tools_status_check check (status in ('available','maintenance'));

alter table public.employees enable row level security;
alter table public.tools enable row level security;
alter table public.loans enable row level security;

create or replace function public.current_employee_role()
returns text language sql stable security definer set search_path=public
as $$ select role from public.employees where lower(email)=lower(auth.jwt()->>'email') and active=true limit 1 $$;

create or replace function public.is_host()
returns boolean language sql stable security definer set search_path=public
as $$ select coalesce(public.current_employee_role()='host',false) $$;


-- Remove policies from the first version so employee permissions cannot bypass the host-only rules.
drop policy if exists "authenticated insert tools" on public.tools;
drop policy if exists "authenticated update tools" on public.tools;
drop policy if exists "authenticated delete tools" on public.tools;
drop policy if exists "authenticated read loans" on public.loans;
drop policy if exists "authenticated insert loans" on public.loans;
drop policy if exists "authenticated update loans" on public.loans;

drop policy if exists "employees read authenticated" on public.employees;
drop policy if exists "employees host insert" on public.employees;
drop policy if exists "employees host update" on public.employees;
drop policy if exists "employees host delete" on public.employees;
create policy "employees read authenticated" on public.employees for select to authenticated using (true);
create policy "employees host insert" on public.employees for insert to authenticated with check (public.is_host());
create policy "employees host update" on public.employees for update to authenticated using (public.is_host()) with check (public.is_host());
create policy "employees host delete" on public.employees for delete to authenticated using (public.is_host());

drop policy if exists "authenticated read tools" on public.tools;
drop policy if exists "authenticated insert tools" on public.tools;
drop policy if exists "authenticated update tools" on public.tools;
drop policy if exists "authenticated delete tools" on public.tools;
create policy "authenticated read tools" on public.tools for select to authenticated using (true);
create policy "host insert tools" on public.tools for insert to authenticated with check (public.is_host());
create policy "host update tools" on public.tools for update to authenticated using (public.is_host()) with check (public.is_host());
create policy "host delete tools" on public.tools for delete to authenticated using (public.is_host());

drop policy if exists "authenticated read loans" on public.loans;
drop policy if exists "authenticated insert loans" on public.loans;
drop policy if exists "authenticated update loans" on public.loans;
create policy "authenticated read loans" on public.loans for select to authenticated using (true);
create policy "authenticated insert loans" on public.loans for insert to authenticated with check (public.is_host() or lower(borrower_email)=lower(auth.jwt()->>'email'));
create policy "authenticated update loans" on public.loans for update to authenticated using (public.is_host() or lower(borrower_email)=lower(auth.jwt()->>'email')) with check (public.is_host() or lower(borrower_email)=lower(auth.jwt()->>'email'));

create unique index if not exists one_open_loan_per_tool on public.loans(tool_id) where returned_at is null;
create unique index if not exists employee_no_unique on public.employees(employee_no);
