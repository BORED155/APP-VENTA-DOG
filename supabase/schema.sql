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

-- 2026-11-14: estado "entregado" (después de enviado).
alter table public.pedidos drop constraint pedidos_estado_check;
alter table public.pedidos add constraint pedidos_estado_check
  check (estado in ('pendiente', 'pagado', 'enviado', 'entregado', 'cancelado'));
drop trigger al_pagar on public.pedidos;
create trigger al_pagar after update of estado on public.pedidos
  for each row when (old.estado = 'pendiente' and new.estado in ('pagado', 'enviado', 'entregado'))
  execute function public.descontar_stock();

-- 2026-11-14: importar respaldos (.json exportados desde la app). Solo el admin.
-- Productos: mismo id → se reemplaza; id nuevo o sin id → se agrega. Se conservan los ids para que
-- los pedidos importados sigan enlazados a sus productos.
create or replace function public.importar_productos(datos jsonb) returns int
language plpgsql security definer set search_path = '' as $$
declare n int;
begin
  if not public.es_admin() then raise exception 'Solo el administrador puede importar'; end if;
  insert into public.productos (id, nombre, descripcion, precio, stock, imagen_url, activo, categoria, creado)
  overriding system value
  select coalesce(x.id, nextval(pg_get_serial_sequence('public.productos', 'id'))),
         x.nombre, coalesce(x.descripcion, ''), x.precio, coalesce(x.stock, 0), x.imagen_url,
         coalesce(x.activo, true), coalesce(x.categoria, 'Otros'), coalesce(x.creado, now())
    from jsonb_to_recordset(datos) as x(id bigint, nombre text, descripcion text, precio numeric,
         stock int, imagen_url text, activo boolean, categoria text, creado timestamptz)
  on conflict (id) do update set nombre = excluded.nombre, descripcion = excluded.descripcion,
    precio = excluded.precio, stock = excluded.stock, imagen_url = excluded.imagen_url,
    activo = excluded.activo, categoria = excluded.categoria;
  get diagnostics n = row_count;
  perform setval(pg_get_serial_sequence('public.productos', 'id'),
                 greatest((select max(id) from public.productos), 1));
  return n;
end $$;
revoke execute on function public.importar_productos(jsonb) from public, anon;
grant execute on function public.importar_productos(jsonb) to authenticated;

-- Pedidos: solo se agregan los que no existen y cuyo cliente sigue registrado. No toca el stock.
create or replace function public.importar_pedidos(datos jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r record; n int := 0; omitidos int := 0;
begin
  if not public.es_admin() then raise exception 'Solo el administrador puede importar'; end if;
  for r in select * from jsonb_to_recordset(datos) as x(id bigint, usuario_id uuid, estado text,
           total numeric, direccion text, creado timestamptz, metodo text, comprobante text,
           pedido_items jsonb) loop
    if exists (select 1 from public.pedidos where id = r.id)
       or not exists (select 1 from public.perfiles where id = r.usuario_id) then
      omitidos := omitidos + 1;
      continue;
    end if;
    insert into public.pedidos (id, usuario_id, estado, total, direccion, creado, metodo, comprobante)
    overriding system value
    values (r.id, r.usuario_id, r.estado, r.total, r.direccion, coalesce(r.creado, now()),
            coalesce(r.metodo, 'tarjeta'), r.comprobante);
    insert into public.pedido_items (pedido_id, producto_id, nombre, precio, cantidad)
    select r.id, (select id from public.productos where id = i.producto_id), i.nombre, i.precio, i.cantidad
      from jsonb_to_recordset(coalesce(r.pedido_items, '[]')) as i(producto_id bigint, nombre text,
           precio numeric, cantidad int);
    n := n + 1;
  end loop;
  perform setval(pg_get_serial_sequence('public.pedidos', 'id'),
                 greatest((select max(id) from public.pedidos), 1));
  return jsonb_build_object('importados', n, 'omitidos', omitidos);
end $$;
revoke execute on function public.importar_pedidos(jsonb) from public, anon;
grant execute on function public.importar_pedidos(jsonb) to authenticated;

-- 2026-11-14: se quita el pago con tarjeta. Los pedidos pendientes con tarjeta pasan a transferencia
-- para que el cliente vea los datos de la cuenta y pueda agregar su comprobante.
update public.pedidos set metodo = 'transferencia' where estado = 'pendiente' and metodo = 'tarjeta';

-- 2026-11-14: el stock se reserva al CREAR el pedido (no al pagarlo), para no vender lo mismo dos veces.
-- Regla: todo pedido que no está cancelado tiene su stock descontado.
--   · cancelar un pedido devuelve el stock · sacarlo de cancelado lo vuelve a descontar.
-- Los pedidos pendientes que ya existían reservan su stock ahora.
update public.productos pr set stock = greatest(pr.stock - i.c, 0)
  from (select it.producto_id, sum(it.cantidad) c
          from public.pedido_items it join public.pedidos p on p.id = it.pedido_id
         where p.estado = 'pendiente' group by it.producto_id) i
 where pr.id = i.producto_id;

drop trigger al_pagar on public.pedidos;
create or replace function public.ajustar_stock() returns trigger
language plpgsql security definer set search_path = '' as $$
declare signo int;
begin
  if new.estado = 'cancelado' then signo := 1;      -- se cancela: vuelve al stock
  elsif old.estado = 'cancelado' then signo := -1;  -- se reactiva: se descuenta otra vez
  else return new;
  end if;
  update public.productos pr set stock = greatest(pr.stock + signo * i.c, 0)
    from (select producto_id, sum(cantidad) c from public.pedido_items
           where pedido_id = new.id group by producto_id) i
   where pr.id = i.producto_id;
  return new;
end $$;
create trigger al_cambiar_estado after update of estado on public.pedidos
  for each row when (old.estado is distinct from new.estado)
  execute function public.ajustar_stock();

create or replace function public.crear_pedido(items jsonb, p_metodo text default 'tarjeta') returns bigint
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
    -- for update: dos clientes a la vez no pueden llevarse la última unidad
    select * into p from public.productos where id = it.pid and activo for update;
    if not found then raise exception 'Un producto ya no está disponible'; end if;
    if it.cant is null or it.cant < 1 or p.stock < it.cant then
      raise exception 'No hay stock suficiente de %', p.nombre;
    end if;
    update public.productos set stock = stock - it.cant where id = p.id;
    insert into public.pedido_items (pedido_id, producto_id, nombre, precio, cantidad)
    values (v_id, p.id, p.nombre, p.precio, it.cant);
    v_total := v_total + p.precio * it.cant;
  end loop;

  update public.pedidos set total = v_total where id = v_id;
  return v_id;
end $$;

-- 2026-11-14: el cliente puede cancelar su pedido mientras esté pendiente (el trigger devuelve el stock).
-- Ya no lo ve en su lista; el admin sí lo sigue viendo como cancelado.
create or replace function public.cancelar_pedido(p_id bigint) returns void
language plpgsql security definer set search_path = '' as $$
begin
  update public.pedidos set estado = 'cancelado'
   where id = p_id and usuario_id = auth.uid() and estado = 'pendiente';
  if not found then
    raise exception 'Solo puedes cancelar pedidos pendientes. Si ya pagaste, escríbenos.';
  end if;
end $$;
revoke execute on function public.cancelar_pedido(bigint) from public, anon;
grant execute on function public.cancelar_pedido(bigint) to authenticated;
