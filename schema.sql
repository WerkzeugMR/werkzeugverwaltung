-- Werkzeugverwaltung - idempotentes Supabase-Schema
-- Host-Konten: Florian@marcoreiss.de, Brian@marcoreiss.de, Büro@marcoreiss.de, bauerhin.b@gmail.com
-- Mitarbeiter-Anmeldung: mitarbeiter@marcoreiss.de

create extension if not exists pgcrypto;

create table if not exists public.tools (
  id uuid primary key default gen_random_uuid(),
  tool_number text not null unique,
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
  email text not null default 'mitarbeiter@marcoreiss.de',
  employee_no char(4) not null unique check (employee_no ~ '^[0-9]{4}$'),
  role text not null default 'employee' check (role in ('employee','host')),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.loans (
  id uuid primary key default gen_random_uuid(),
  tool_id uuid not null references public.tools(id) on delete restrict,
  employee_id uuid references public.employees(id) on delete set null,
  employee_no char(4) not null check (employee_no ~ '^[0-9]{4}$'),
  employee_name text,
  borrower_email text,
  department text,
  checkout_note text,
  return_note text,
  checked_out_by uuid,
  checked_out_at timestamptz not null default now(),
  returned_by uuid,
  returned_at timestamptz
);

create unique index if not exists one_open_loan_per_tool on public.loans(tool_id) where returned_at is null;
create index if not exists loans_checked_out_at_idx on public.loans(checked_out_at);

alter table public.tools enable row level security;
alter table public.employees enable row level security;
alter table public.loans enable row level security;

-- Alte Policies sicher entfernen
 drop policy if exists "tools_select_authenticated" on public.tools;
 drop policy if exists "tools_insert_host" on public.tools;
 drop policy if exists "tools_update_host" on public.tools;
 drop policy if exists "tools_delete_host" on public.tools;
 drop policy if exists "host select tools" on public.tools;
 drop policy if exists "host insert tools" on public.tools;
 drop policy if exists "host update tools" on public.tools;
 drop policy if exists "host delete tools" on public.tools;
 drop policy if exists "employees_select_host" on public.employees;
 drop policy if exists "employees_insert_host" on public.employees;
 drop policy if exists "employees_update_host" on public.employees;
 drop policy if exists "employees_delete_host" on public.employees;
 drop policy if exists "loans_select_host" on public.loans;
 drop policy if exists "loans_insert_host" on public.loans;
 drop policy if exists "loans_update_host" on public.loans;
 drop policy if exists "loans_delete_host" on public.loans;

create or replace function public.is_host_email(p_email text)
returns boolean
language sql
immutable
as $$
  select lower(coalesce(p_email,'')) = any(array[
    'florian@marcoreiss.de',
    'brian@marcoreiss.de',
    'büro@marcoreiss.de',
    'buero@marcoreiss.de',
    'bauerhin.b@gmail.com'
  ]);
$$;

create policy "tools_select_authenticated" on public.tools for select to authenticated using (true);
create policy "tools_insert_host" on public.tools for insert to authenticated with check (public.is_host_email(auth.jwt()->>'email'));
create policy "tools_update_host" on public.tools for update to authenticated using (public.is_host_email(auth.jwt()->>'email')) with check (public.is_host_email(auth.jwt()->>'email'));
create policy "tools_delete_host" on public.tools for delete to authenticated using (public.is_host_email(auth.jwt()->>'email'));

create policy "employees_select_host" on public.employees for select to authenticated using (public.is_host_email(auth.jwt()->>'email'));
create policy "employees_insert_host" on public.employees for insert to authenticated with check (public.is_host_email(auth.jwt()->>'email'));
create policy "employees_update_host" on public.employees for update to authenticated using (public.is_host_email(auth.jwt()->>'email')) with check (public.is_host_email(auth.jwt()->>'email'));
create policy "employees_delete_host" on public.employees for delete to authenticated using (public.is_host_email(auth.jwt()->>'email'));

create policy "loans_select_host" on public.loans for select to authenticated using (public.is_host_email(auth.jwt()->>'email'));
create policy "loans_insert_host" on public.loans for insert to authenticated with check (public.is_host_email(auth.jwt()->>'email'));
create policy "loans_update_host" on public.loans for update to authenticated using (public.is_host_email(auth.jwt()->>'email')) with check (public.is_host_email(auth.jwt()->>'email'));
create policy "loans_delete_host" on public.loans for delete to authenticated using (public.is_host_email(auth.jwt()->>'email'));

create or replace function public.get_open_loans_safe()
returns table(tool_id uuid, tool_number text, tool_name text, employee_name text, checked_out_at timestamptz, department text, checkout_note text)
language sql
security definer
set search_path = public
as $$
  select l.tool_id,t.tool_number,t.name,
         coalesce(l.employee_name,e.name,'') as employee_name,
         l.checked_out_at,l.department,l.checkout_note
  from public.loans l
  join public.tools t on t.id=l.tool_id
  left join public.employees e on e.id=l.employee_id
  where l.returned_at is null
  order by l.checked_out_at desc;
$$;

grant execute on function public.get_open_loans_safe() to authenticated;

create or replace function public.checkout_tool(p_tool_id uuid,p_employee_no text,p_note text default null,p_department text default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_emp public.employees%rowtype;
  v_loan_id uuid;
  v_email text := lower(coalesce(auth.jwt()->>'email',''));
begin
  if v_email <> lower('mitarbeiter@marcoreiss.de') then
    raise exception 'Nur das Mitarbeiterkonto darf Mitarbeiter-Ausgaben buchen.';
  end if;

  select * into v_emp from public.employees
  where employee_no=left(coalesce(p_employee_no,''),4)
    and active=true
    and lower(email)=lower('mitarbeiter@marcoreiss.de')
  limit 1;

  if not found then raise exception 'Kennnummer nicht gefunden oder deaktiviert.'; end if;

  if not exists(select 1 from public.tools where id=p_tool_id and status='available') then
    raise exception 'Werkzeug ist nicht verfügbar.';
  end if;

  if exists(select 1 from public.loans where tool_id=p_tool_id and returned_at is null) then
    raise exception 'Werkzeug ist bereits ausgeliehen.';
  end if;

  insert into public.loans(tool_id,employee_id,employee_no,employee_name,borrower_email,department,checkout_note,checked_out_by)
  values(p_tool_id,v_emp.id,v_emp.employee_no,v_emp.name,'mitarbeiter@marcoreiss.de',p_department,p_note,auth.uid())
  returning id into v_loan_id;

  return v_loan_id;
end;
$$;

grant execute on function public.checkout_tool(uuid,text,text,text) to authenticated;

create or replace function public.return_tool(p_tool_id uuid,p_employee_no text,p_return_note text default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_loan public.loans%rowtype;
  v_emp public.employees%rowtype;
  v_email text := lower(coalesce(auth.jwt()->>'email',''));
begin
  if v_email <> lower('mitarbeiter@marcoreiss.de') then
    raise exception 'Nur das Mitarbeiterkonto darf Mitarbeiter-Rückgaben buchen.';
  end if;

  select * into v_loan from public.loans
  where tool_id=p_tool_id and returned_at is null
    and employee_no=left(coalesce(p_employee_no,''),4)
  order by checked_out_at desc limit 1;
  if not found then raise exception 'Für diese Kennnummer gibt es keine offene Ausgabe dieses Werkzeugs.'; end if;

  update public.loans
  set returned_at=now(),returned_by=auth.uid(),return_note=p_return_note
  where id=v_loan.id;
  return v_loan.id;
end;
$$;

grant execute on function public.return_tool(uuid,text,text) to authenticated;

create or replace function public.delete_employee(p_employee_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
begin
  if not public.is_host_email(auth.jwt()->>'email') then raise exception 'Nur der Host darf Mitarbeiter löschen.'; end if;
  select name into v_name from public.employees where id=p_employee_id;
  if v_name is null then raise exception 'Mitarbeiter nicht gefunden.'; end if;
  update public.loans set employee_name=coalesce(employee_name,v_name),employee_id=null where employee_id=p_employee_id;
  delete from public.employees where id=p_employee_id;
  return true;
end;
$$;

grant execute on function public.delete_employee(uuid) to authenticated;
