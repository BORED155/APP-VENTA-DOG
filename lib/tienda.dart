import 'package:material_ui/material_ui.dart';

import 'admin.dart';
import 'carrito.dart';
import 'main.dart';
import 'pedidos.dart';
import 'perfil.dart';

String dinero(num v) => '\$${v.toStringAsFixed(2)}';

Widget foto(Map p, {double alto = 120}) => Builder(
  builder: (c) {
    final cs = Theme.of(c).colorScheme;
    final sinFoto = Container(
      height: alto,
      width: double.infinity,
      color: cs.primaryContainer,
      child: Icon(Icons.pets, size: alto * 0.4, color: cs.primary),
    );
    return p['imagen_url'] == null
        ? sinFoto
        : Image.network(
            p['imagen_url'],
            height: alto,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => sinFoto,
          );
  },
);

/// Ventana con la foto grande (se puede ampliar con los dedos o la rueda) y el detalle del producto.
Future<void> verDetalle(BuildContext context, Map p) => showDialog(
  context: context,
  builder: (c) {
    final t = Theme.of(c);
    final stock = p['stock'] as int;
    final desc = '${p['descripcion'] ?? ''}'.trim();
    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.sizeOf(c).height * 0.85,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  Container(
                    height: 320,
                    width: double.infinity,
                    color: t.colorScheme.surfaceContainerHighest,
                    child: p['imagen_url'] == null
                        ? Icon(
                            Icons.pets,
                            size: 120,
                            color: t.colorScheme.primary,
                          )
                        : InteractiveViewer(
                            maxScale: 4,
                            child: Image.network(
                              p['imagen_url'],
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.broken_image, size: 80),
                            ),
                          ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton.filledTonal(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.pop(c),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p['nombre'],
                      style: t.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          dinero(p['precio']),
                          style: t.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: t.colorScheme.primary,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: stock == 0
                                ? t.colorScheme.errorContainer
                                : t.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            stock == 0 ? 'Agotado' : '$stock disponibles',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    Text(
                      'Descripción',
                      style: t.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      desc.isEmpty
                          ? 'Este producto aún no tiene descripción.'
                          : desc,
                      style: t.textTheme.bodyLarge?.copyWith(height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  },
);

/// Píldora ⊖ n ⊕ usada en las tarjetas y en el carrito.
Widget selector(
  BuildContext c,
  int n,
  VoidCallback? menos,
  VoidCallback? mas,
) => Container(
  decoration: BoxDecoration(
    color: Theme.of(c).colorScheme.surfaceContainerHighest,
    borderRadius: BorderRadius.circular(30),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: 'Menos',
        onPressed: menos,
        icon: const Icon(Icons.remove, size: 18),
      ),
      Text(
        '$n',
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
      IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: 'Más',
        onPressed: mas,
        icon: const Icon(Icons.add, size: 18),
      ),
    ],
  ),
);

/// Pantalla principal tras entrar: barra inferior con Tienda, Pedidos, Perfil y (si es admin) Admin.
class Tienda extends StatefulWidget {
  const Tienda({super.key});
  @override
  State<Tienda> createState() => _TiendaState();
}

class _TiendaState extends State<Tienda> {
  int tab = 0;
  bool admin = false;
  String nombre = '';

  @override
  void initState() {
    super.initState();
    sb
        .from('perfiles')
        .select('nombre, es_admin')
        .eq('id', sb.auth.currentUser!.id)
        .maybeSingle()
        .then((yo) {
          if (mounted) {
            setState(() {
              admin = yo?['es_admin'] == true;
              nombre = '${yo?['nombre'] ?? ''}'.split(' ').first;
            });
          }
        }, onError: (e) => mounted ? aviso(context, e) : null);
  }

  @override
  Widget build(BuildContext context) {
    final paginas = <Widget>[
      Catalogo(nombre: nombre),
      Pedidos(admin: admin),
      const Perfil(),
      if (admin) const AdminProductos(),
    ];
    return Scaffold(
      body: paginas[tab.clamp(0, paginas.length - 1)],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab.clamp(0, paginas.length - 1),
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Tienda',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Pedidos',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
          if (admin)
            const NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2),
              label: 'Admin',
            ),
        ],
      ),
    );
  }
}

class Catalogo extends StatefulWidget {
  const Catalogo({super.key, required this.nombre});
  final String nombre;
  @override
  State<Catalogo> createState() => _CatalogoState();
}

class _CatalogoState extends State<Catalogo> {
  List<Map<String, dynamic>> productos = [];
  String filtro = '';
  String? cat; // categoría elegida; null = todas
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future<void> cargar() async {
    try {
      final p = await sb
          .from('productos')
          .select()
          .eq('activo', true)
          .order('nombre', ascending: true);
      if (mounted) setState(() => productos = p);
    } catch (e) {
      if (mounted) aviso(context, e);
    }
    if (mounted) setState(() => cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final f = filtro.toLowerCase();
    final categorias = {for (final p in productos) '${p['categoria']}'}.toList()
      ..sort();
    final visibles = productos
        .where(
          (p) =>
              (cat == null || p['categoria'] == cat) &&
              '${p['nombre']} ${p['descripcion']} ${p['categoria']}'
                  .toLowerCase()
                  .contains(f),
        )
        .toList();
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: cargar,
        child: CustomScrollView(
          slivers: [
            SliverSafeArea(
              bottom: false,
              sliver: SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverList.list(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.nombre.isEmpty
                                    ? '¡Hola! 👋'
                                    : '¡Hola, ${widget.nombre}! 👋',
                                style: t.textTheme.titleMedium?.copyWith(
                                  color: t.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                '¿Qué necesita tu perro hoy?',
                                style: t.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ValueListenableBuilder(
                          valueListenable: carrito,
                          builder: (_, _, _) => Material(
                            color: Colors.transparent,
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: degradado,
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(30),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const CarritoPantalla(),
                                  ),
                                ).then((_) => cargar()),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Badge(
                                        isLabelVisible: unidades() > 0,
                                        label: Text('${unidades()}'),
                                        child: Image.asset(
                                          'assets/perro_bolsa.png',
                                          width: 30,
                                          height: 30,
                                          color: Colors.white,
                                          semanticLabel: 'Ver carrito',
                                        ),
                                      ),
                                      if (unidades() > 0) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          dinero(total()),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      onChanged: (v) => setState(() => filtro = v),
                      decoration: const InputDecoration(
                        hintText: 'Buscar collares, comida, juguetes…',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: degradado,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: turquesa.withValues(alpha: 0.35),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Consiente a tu peludo 🐶',
                                  style: t.textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Envío a domicilio · Paga por transferencia bancaria',
                                  style: t.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.95),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.pets, size: 64, color: amarillo),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Text(
                          'Productos',
                          style: t.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!cargando)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: t.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${visibles.length}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: t.colorScheme.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (categorias.length > 1)
                      SizedBox(
                        height: 42,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final c in [null, ...categorias])
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(c ?? 'Todas'),
                                  selected: cat == c,
                                  showCheckmark: false,
                                  shape: const StadiumBorder(),
                                  labelStyle: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: cat == c
                                        ? t.colorScheme.onPrimary
                                        : null,
                                  ),
                                  selectedColor: t.colorScheme.primary,
                                  onSelected: (_) => setState(() => cat = c),
                                ),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            if (cargando)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (visibles.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: vacio(
                  Icons.search_off,
                  productos.isEmpty
                      ? 'Aún no hay productos.\nVuelve pronto 🐾'
                      : 'No encontramos "$filtro"',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 260,
                    mainAxisExtent: 330,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: visibles.length,
                  itemBuilder: (_, i) => _Tarjeta(visibles[i]),
                ),
              ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ), // espacio para el botón del carrito
          ],
        ),
      ),
    );
  }
}

class _Tarjeta extends StatefulWidget {
  const _Tarjeta(this.p);
  final Map<String, dynamic> p;
  @override
  State<_Tarjeta> createState() => _TarjetaState();
}

class _TarjetaState extends State<_Tarjeta> {
  int elegida = 1;

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final t = Theme.of(context);
    return ValueListenableBuilder(
      valueListenable: carrito,
      builder: (_, lineas, _) {
        final stock = p['stock'] as int;
        final enCarrito = lineas[p['id']]?.cantidad ?? 0;
        final libres = stock - enCarrito; // lo que aún se puede añadir
        final cant = elegida.clamp(1, libres < 1 ? 1 : libres);
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => verDetalle(context, p),
                      child: foto(p, alto: 150),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: IgnorePointer(
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.black.withValues(alpha: 0.45),
                        child: const Icon(
                          Icons.zoom_in,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: stock == 0 ? t.colorScheme.error : amarillo,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        stock == 0 ? 'Agotado' : '$stock disponibles',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: stock == 0 ? Colors.white : textoSobreAmarillo,
                        ),
                      ),
                    ),
                  ),
                  if (enCarrito > 0)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: t.colorScheme.primary,
                        child: Text(
                          '$enCarrito',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: t.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p['nombre'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      p['descripcion'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.bodySmall?.copyWith(
                        color: t.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dinero(p['precio']),
                      style: t.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: t.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: libres < 1
                    ? SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonal(
                          onPressed: null,
                          child: Text(
                            stock == 0 ? 'Agotado' : 'Todo en tu carrito',
                          ),
                        ),
                      )
                    : Row(
                        children: [
                          selector(
                            context,
                            cant,
                            cant > 1
                                ? () => setState(() => elegida = cant - 1)
                                : null,
                            cant < libres
                                ? () => setState(() => elegida = cant + 1)
                                : null,
                          ),
                          const Spacer(),
                          IconButton.filled(
                            tooltip: 'Agregar $cant al carrito',
                            style: IconButton.styleFrom(
                              padding: const EdgeInsets.all(12),
                            ),
                            onPressed: () {
                              cambiarCantidad(p, cant);
                              setState(() => elegida = 1);
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '$cant × ${p['nombre']} añadido al carrito 🛒',
                                    ),
                                  ),
                                );
                            },
                            icon: const Icon(Icons.add_shopping_cart),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class CarritoPantalla extends StatefulWidget {
  const CarritoPantalla({super.key});
  @override
  State<CarritoPantalla> createState() => _CarritoPantallaState();
}

class _CarritoPantallaState extends State<CarritoPantalla> {
  bool ocupado = false;

  Future<void> _comprar() async {
    setState(() => ocupado = true);
    try {
      final id = await sb.rpc(
        'crear_pedido',
        params: {'items': itemsParaPedido(), 'p_metodo': 'transferencia'},
      ) as int;
      carrito.value = {};
      if (!mounted) return;
      final p = await sb.from('pedidos').select('total').eq('id', id).single();
      if (mounted) await mostrarTransferencia(context, id, p['total']);
      if (mounted)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const Pedidos()),
        );
    } catch (e) {
      if (mounted) aviso(context, e);
    }
    if (mounted) setState(() => ocupado = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Tu carrito')),
      body: ValueListenableBuilder(
        valueListenable: carrito,
        builder: (_, lineas, _) => lineas.isEmpty
            ? vacio(
                Icons.shopping_bag_outlined,
                'Tu carrito está vacío.\n¡Agrega algo para tu peludo! 🐾',
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: lineas.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final l = lineas.values.elementAt(i);
                        final pr = l.producto;
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: SizedBox(
                                    width: 72,
                                    height: 72,
                                    child: foto(pr, alto: 72),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        pr['nombre'],
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        '${dinero(pr['precio'])} c/u',
                                        style: TextStyle(
                                          color: t.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        dinero(
                                          (pr['precio'] as num) * l.cantidad,
                                        ),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: t.colorScheme.primary,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                selector(
                                  context,
                                  l.cantidad,
                                  () => cambiarCantidad(pr, -1),
                                  l.cantidad < (pr['stock'] as int)
                                      ? () => cambiarCantidad(pr, 1)
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    decoration: BoxDecoration(
                      color: t.colorScheme.surfaceContainerLowest,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 20,
                          offset: Offset(0, -4),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${unidades()} artículos',
                                style: t.textTheme.titleMedium,
                              ),
                              const Spacer(),
                              Text(
                                dinero(total()),
                                style: t.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: ocupado ? null : _comprar,
                            icon: const Icon(Icons.account_balance),
                            label: const Text(
                              'Pagar por transferencia bancaria',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
