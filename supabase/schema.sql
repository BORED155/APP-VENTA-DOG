-- APP VENTA DOG: pegar entero en Supabase > SQL Editor y ejecutar una vez.

-- ── Perfiles (se crean solos al registrarse) ────────────────────────────
create table public.perfiles (
  id        uuid primary key references auth.users on delete cascade,
  nombre    text not null default '',
  telefono  text not null default '',
  direccion text not null default '',
  ciudad    text not null default '',
  es_admin  boolean not null default false
);
create function public.es_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce((select es_admin from public.perfiles where id = auth.uid()), false)
$$;
alter table public.perfiles enable row level security;
create policy "ve su perfil" on public.perfiles for select to authenticated
  using (id = auth.uid() or public.es_admin());
create policy "edita su perfil" on public.perfiles for update to authenticated using (id = auth.uid());
-- nadie puede ponerse es_admin a sí mismo: solo estas columnas son editables
revoke insert, update, delete on public.perfiles from anon, authenticated;
grant select on public.perfiles to authenticated;
grant update (nombre, telefono, direccion, ciudad) on public.perfiles to authenticated;

create function public.nuevo_usuario() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.perfiles (id, nombre, telefono, direccion, ciudad)
  values (new.id,
          coalesce(new.raw_user_meta_data->>'nombre', ''),
          coalesce(new.raw_user_meta_data->>'telefono', ''),
          coalesce(new.raw_user_meta_data->>'direccion', ''),
          coalesce(new.raw_user_meta_data->>'ciudad', ''));
  return new;
end $$;
create trigger al_registrarse after insert on auth.users
  for each row execute function public.nuevo_usuario();


-- ── Productos ───────────────────────────────────────────────────────────
create table public.productos (
  id          bigint generated always as identity primary key,
  nombre      text not null,
  descripcion text not null default '',
  precio      numeric(10,2) not null check (precio > 0),
  stock       int not null default 0 check (stock >= 0),
  imagen_url  text,
  activo      boolean not null default true,
  creado      timestamptz not null default now()
);
alter table public.productos enable row level security;
create policy "todos ven productos activos" on public.productos for select using (activo or public.es_admin());
create policy "admin gestiona productos" on public.productos for all to authenticated
  using (public.es_admin()) with check (public.es_admin());
grant select on public.productos to anon, authenticated;
grant insert, update, delete on public.productos to authenticated;

-- ── Pedidos ─────────────────────────────────────────────────────────────
create table public.pedidos (
  id         bigint generated always as identity primary key,
  usuario_id uuid not null references public.perfiles on delete cascade,
  estado     text not null default 'pendiente'
             check (estado in ('pendiente', 'pagado', 'enviado', 'cancelado')),
  total      numeric(10,2) not null,
  direccion  text not null,
  creado     timestamptz not null default now()
);
create table public.pedido_items (
  pedido_id   bigint not null references public.pedidos on delete cascade,
  producto_id bigint not null references public.productos,
  nombre      text not null,
  precio      numeric(10,2) not null,
  cantidad    int not null check (cantidad > 0),
  primary key (pedido_id, producto_id)
);
alter table public.pedidos enable row level security;
alter table public.pedido_items enable row level security;
create policy "ve sus pedidos" on public.pedidos for select to authenticated
  using (usuario_id = auth.uid() or public.es_admin());
create policy "admin cambia estado" on public.pedidos for update to authenticated
  using (public.es_admin()) with check (public.es_admin());
create policy "ve sus items" on public.pedido_items for select to authenticated
  using (exists (select 1 from public.pedidos p where p.id = pedido_id
                 and (p.usuario_id = auth.uid() or public.es_admin())));
revoke insert, update, delete on public.pedidos, public.pedido_items from anon, authenticated;
grant select on public.pedidos, public.pedido_items to authenticated;
grant update (estado) on public.pedidos to authenticated;

-- El cliente solo manda ids y cantidades; precio y total salen de la base (nunca del teléfono).
create function public.crear_pedido(items jsonb) returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_id bigint; v_total numeric := 0; v_perfil public.perfiles; it record; p public.productos;
begin
  if auth.uid() is null then raise exception 'Inicia sesión'; end if;
  select * into v_perfil from public.perfiles where id = auth.uid();
  if coalesce(trim(v_perfil.direccion), '') = '' then
    raise exception 'Completa tu dirección en Mi perfil';
  end if;
  if coalesce(jsonb_array_length(items), 0) = 0 then raise exception 'El carrito está vacío'; end if;

  insert into public.pedidos (usuario_id, total, direccion)
  values (auth.uid(), 0, concat_ws(', ', v_perfil.direccion, nullif(v_perfil.ciudad, '')))
  returning id into v_id;

  for it in select (e->>'producto_id')::bigint as pid, (e->>'cantidad')::int as cant
            from jsonb_array_elements(items) e loop
    select * into p from public.productos where id = it.pid and activo;
    if not found then raise exception 'Un producto ya no está disponible'; end if;
    if it.cant is null or it.cant < 1 or p.stock < it.cant then
      raise exception 'No hay stock suficiente de %', p.nombre;
    end if;
    insert into public.pedido_items values (v_id, p.id, p.nombre, p.precio, it.cant);
    v_total := v_total + p.precio * it.cant;
  end loop;

  update public.pedidos set total = v_total where id = v_id;
  return v_id;
end $$;
revoke execute on function public.crear_pedido(jsonb) from public, anon;
grant execute on function public.crear_pedido(jsonb) to authenticated;

-- Solo la función de servidor "confirmar" (service_role) la llama, tras aprobar PayPhone.
create function public.marcar_pagado(p_id bigint) returns void
language sql security definer set search_path = '' as $$
  update public.productos pr set stock = greatest(pr.stock - i.cantidad, 0)
    from public.pedido_items i
   where i.pedido_id = p_id and pr.id = i.producto_id
     and exists (select 1 from public.pedidos where id = p_id and estado = 'pendiente');
  update public.pedidos set estado = 'pagado' where id = p_id and estado = 'pendiente';
$$;
revoke execute on function public.marcar_pagado(bigint) from public, anon, authenticated;

-- ── Fotos de productos ──────────────────────────────────────────────────
insert into storage.buckets (id, name, public) values ('productos', 'productos', true)
  on conflict (id) do nothing;
create policy "admin sube fotos" on storage.objects for insert to authenticated
  with check (bucket_id = 'productos' and public.es_admin());
create policy "admin cambia fotos" on storage.objects for update to authenticated
  using (bucket_id = 'productos' and public.es_admin());
create policy "admin borra fotos" on storage.objects for delete to authenticated
  using (bucket_id = 'productos' and public.es_admin());

-- ── Hacer administrador a una cuenta (después de registrarla en la app) ─
-- update public.perfiles set es_admin = true
--  where id = (select id from auth.users where email = 'TU_CORREO@ejemplo.com');
-- 2026-11-14: pago por transferencia + descontar stock al pasar a pagado (sea tarjeta o manual).
alter table public.pedidos add column metodo text not null default 'tarjeta'
  check (metodo in ('tarjeta', 'transferencia'));

create or replace function public.descontar_stock() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.productos pr set stock = greatest(pr.stock - i.cantidad, 0)
    from public.pedido_items i
   where i.pedido_id = new.id and pr.id = i.producto_id;
  return new;
end $$;
create trigger al_pagar after update of estado on public.pedidos
  for each row when (old.estado = 'pendiente' and new.estado in ('pagado', 'enviado'))
  execute function public.descontar_stock();

create or replace function public.marcar_pagado(p_id bigint) returns void
language sql security definer set search_path = '' as $$
  update public.pedidos set estado = 'pagado' where id = p_id and estado = 'pendiente';
$$;
revoke execute on function public.marcar_pagado(bigint) from public, anon, authenticated;

drop function public.crear_pedido(jsonb);
create function public.crear_pedido(items jsonb, p_metodo text default 'tarjeta') returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_id bigint; v_total numeric := 0; v_perfil public.perfiles; it record; p public.productos;
begin
  if auth.uid() is null then raise exception 'Inicia sesión'; end if;
  select * into v_perfil from public.perfiles where id = auth.uid();
  if coalesce(trim(v_perfil.direccion), '') = '' then
    raise exception 'Completa tu dirección en Mi perfil';
  end if;
  if coalesce(jsonb_array_length(items), 0) = 0 then raise exception 'El carrito está vacío'; end if;

  insert into public.pedidos (usuario_id, total, direccion, metodo)
  values (auth.uid(), 0, concat_ws(', ', v_perfil.direccion, nullif(v_perfil.ciudad, '')), p_metodo)
  returning id into v_id;

  for it in select (e->>'producto_id')::bigint as pid, (e->>'cantidad')::int as cant
            from jsonb_array_elements(items) e loop
    select * into p from public.productos where id = it.pid and activo;
    if not found then raise exception 'Un producto ya no está disponible'; end if;
    if it.cant is null or it.cant < 1 or p.stock < it.cant then
      raise exception 'No hay stock suficiente de %', p.nombre;
    end if;
    insert into public.pedido_items values (v_id, p.id, p.nombre, p.precio, it.cant);
    v_total := v_total + p.precio * it.cant;
  end loop;

  update public.pedidos set total = v_total where id = v_id;
  return v_id;
end $$;
revoke execute on function public.crear_pedido(jsonb, text) from public, anon;
grant execute on function public.crear_pedido(jsonb, text) to authenticated;

-- 2026-11-14: categorías de producto (filtros en la tienda).
alter table public.productos add column categoria text not null default 'Otros';

-- 2026-11-14: poder borrar productos que ya están en pedidos. La línea del pedido guarda su propio
-- nombre y precio, así que el historial no se pierde: solo queda sin enlace al producto borrado.
alter table public.pedido_items drop constraint pedido_items_pkey;
alter table public.pedido_items alter column producto_id drop not null;
alter table public.pedido_items drop constraint pedido_items_producto_id_fkey;
alter table public.pedido_items add constraint pedido_items_producto_id_fkey
  foreign key (producto_id) references public.productos on delete set null;
alter table public.pedido_items add column id bigint generated always as identity primary key;

-- 2026-11-14: el cliente anota el número de comprobante de su transferencia (el admin lo ve en el pedido).
alter table public.pedidos add column comprobante text;
create function public.poner_comprobante(p_id bigint, p_numero text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if coalesce(trim(p_numero), '') = '' or length(p_numero) > 60 then
    raise exception 'Escribe un número de comprobante válido';
  end if;
  update public.pedidos set comprobante = trim(p_numero)
   where id = p_id and usuario_id = auth.uid() and estado = 'pendiente' and metodo = 'transferencia';
  if not found then raise exception 'Ese pedido ya no acepta comprobante'; end if;
end $$;
revoke execute on function public.poner_comprobante(bigint, text) from public, anon;
grant execute on function public.poner_comprobante(bigint, text) to authenticated;
