-- Werkzeugverwaltung: Basis + Mitarbeiter
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

create table if not exists public.employees (
 id uuid primary key default gen_random_uuid(),
 name text not null,
 email text not null default 'mitarbeiter@marcoreiss.com',
 employee_no char(4) not null unique,
 role text not null default 'employee' check (role in ('employee','host')),
 active boolean not null default true,
 created_at timestamptz not null default now()
);

create table if not exists public.loans (
 id uuid primary key default gen_random_uuid(),
 tool_id uuid not null references public.tools(id) on delete restrict,
 employee_id uuid references public.employees(id) on delete restrict,
 employee_no char(4),
 borrower_email text not null,
 department text,
 checkout_note text,
 return_note text,
 checked_out_by uuid references auth.users(id),
 checked_out_at timestamptz not null default now(),
 returned_by uuid references auth.users(id),
 returned_at timestamptz
);

alter table public.loans add column if not exists employee_id uuid references public.employees(id) on delete restrict;
alter table public.loans add column if not exists employee_no char(4);
alter table public.loans add column if not exists checkout_note text;
alter table public.loans add column if not exists return_note text;

alter table public.tools enable row level security;
alter table public.loans enable row level security;
alter table public.employees enable row level security;

drop policy if exists "authenticated read tools" on public.tools;
drop policy if exists "authenticated insert tools" on public.tools;
drop policy if exists "authenticated update tools" on public.tools;
drop policy if exists "authenticated delete tools" on public.tools;

create policy "authenticated read tools" on public.tools for select to authenticated using (true);
create policy "host insert tools" on public.tools for insert to authenticated with check (lower(auth.jwt()->>'email')='bauerhin.b@gmail.com');
create policy "host update tools" on public.tools for update to authenticated using (lower(auth.jwt()->>'email')='bauerhin.b@gmail.com') with check (lower(auth.jwt()->>'email')='bauerhin.b@gmail.com');
create policy "host delete tools" on public.tools for delete to authenticated using (lower(auth.jwt()->>'email')='bauerhin.b@gmail.com');

drop policy if exists "authenticated read loans" on public.loans;
drop policy if exists "authenticated insert loans" on public.loans;
drop policy if exists "authenticated update loans" on public.loans;

create policy "authenticated read loans" on public.loans for select to authenticated using (true);
create policy "authenticated insert loans" on public.loans for insert to authenticated with check (true);
create policy "authenticated update loans" on public.loans for update to authenticated using (true) with check (true);

drop policy if exists "employees read" on public.employees;
drop policy if exists "employees host insert" on public.employees;
drop policy if exists "employees host update" on public.employees;

create policy "employees read" on public.employees for select to authenticated using (true);
create policy "employees host insert" on public.employees for insert to authenticated with check (lower(auth.jwt()->>'email')='bauerhin.b@gmail.com');
create policy "employees host update" on public.employees for update to authenticated using (lower(auth.jwt()->>'email')='bauerhin.b@gmail.com') with check (lower(auth.jwt()->>'email')='bauerhin.b@gmail.com');

create unique index if not exists one_open_loan_per_tool on public.loans(tool_id) where returned_at is null;

-- Kennnummer prüfen: liefert genau den aktiven Mitarbeiter zur 4-stelligen Kennnummer.
create or replace function public.verify_employee_code(p_code text)
returns table(id uuid, name text, email text, employee_no char(4))
language sql
security definer
set search_path=public
as $$
  select e.id, e.name, e.email, e.employee_no
  from public.employees e
  where e.employee_no=p_code and e.active=true and e.role='employee'
  limit 1;
$$;

revoke all on function public.verify_employee_code(text) from public;
grant execute on function public.verify_employee_code(text) to authenticated;

create index if not exists idx_loans_checked_out_at on public.loans(checked_out_at desc);


-- Reparatur/Fix: Mitarbeiterverwaltung und Kennnummernprüfung
alter table public.employees alter column email set default 'mitarbeiter@marcoreiss.com';

drop policy if exists "employees read" on public.employees;
drop policy if exists "employees host insert" on public.employees;
drop policy if exists "employees host update" on public.employees;

create policy "employees read" on public.employees
for select to authenticated
using (true);

create policy "employees host insert" on public.employees
for insert to authenticated
with check (lower(coalesce(auth.jwt()->>'email',''))='bauerhin.b@gmail.com');

create policy "employees host update" on public.employees
for update to authenticated
using (lower(coalesce(auth.jwt()->>'email',''))='bauerhin.b@gmail.com')
with check (lower(coalesce(auth.jwt()->>'email',''))='bauerhin.b@gmail.com');

drop function if exists public.verify_employee_code(text);
create or replace function public.verify_employee_code(p_code text)
returns table(id uuid, name text, email text, employee_no char(4))
language sql
security definer
set search_path=public
as $$
  select e.id, e.name, e.email, e.employee_no
  from public.employees e
  where trim(e.employee_no::text)=trim(p_code)
    and e.active=true
    and e.role='employee'
  limit 1;
$$;

revoke all on function public.verify_employee_code(text) from public;
grant execute on function public.verify_employee_code(text) to authenticated;


-- Host: Mitarbeiter endgültig löschen, bisherige Ausleihen bleiben erhalten
alter table public.loans add column if not exists employee_name text;

create or replace function public.delete_employee(p_employee_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
begin
  if lower(coalesce(auth.jwt()->>'email','')) <> 'bauerhin.b@gmail.com' then
    raise exception 'Nur der Host darf Mitarbeiter löschen.';
  end if;

  select name into v_name
  from public.employees
  where id = p_employee_id;

  if v_name is null then
    raise exception 'Mitarbeiter wurde nicht gefunden.';
  end if;

  update public.loans
  set employee_name = coalesce(employee_name, v_name),
      employee_id = null
  where employee_id = p_employee_id;

  delete from public.employees
  where id = p_employee_id;
end;
$$;

revoke all on function public.delete_employee(uuid) from public;
grant execute on function public.delete_employee(uuid) to authenticated;
