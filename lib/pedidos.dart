import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'main.dart';
import 'respaldo.dart';
import 'tienda.dart';

// shortcut: datos fijos en el código; si cambia la cuenta, editar aquí y recompilar.
const cuentaNumero = '12005458809';
const cuentaTexto =
    'Banco: Produbanco\nTipo: Cuenta de ahorros\nNúmero: $cuentaNumero\nTitular: Lenin Solorzano';

Future<void> mostrarTransferencia(BuildContext c, int id, num total) =>
    showDialog(
      context: c,
      builder: (c) => AlertDialog(
        title: Text('Pedido #$id: transferencia'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transfiere ${dinero(total)} a:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const SelectableText(cuentaTexto),
            const SizedBox(height: 12),
            Text('En el concepto o descripción escribe: Pedido #$id'),
            const SizedBox(height: 8),
            const Text(
              'Al terminar, pulsa "Agregar comprobante" en Pedidos y escribe el número que te dio el banco. '
              'Cuando confirmemos el depósito, tu pedido pasará a "pagado" y te avisaremos por WhatsApp.',
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: cuentaNumero));
              ScaffoldMessenger.of(c).showSnackBar(
                const SnackBar(content: Text('Número de cuenta copiado')),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copiar número'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );

/// Número para wa.me: solo dígitos y con código de Ecuador (0991234567 → 593991234567).
String numeroWhatsapp(String tel) {
  final d = tel.replaceAll(RegExp(r'\D'), '');
  return d.startsWith('0') ? '593${d.substring(1)}' : d;
}

/// Enlace de WhatsApp con el aviso al cliente, o null si ese estado no avisa (pendiente, cancelado)
/// o no hay teléfono. Cancelar no avisa: solo devuelve el stock (lo hace la base).
Uri? avisoWhatsapp(Map<String, dynamic> p, String estado) {
  final cliente = p['perfiles'] ?? {};
  final numero = numeroWhatsapp('${cliente['telefono'] ?? ''}');
  final hola =
      'Hola ${cliente['nombre'] ?? ''}, te escribimos de APP VENTA DOG.';
  final texto = switch (estado) {
    'pagado' =>
      '$hola Confirmamos el pago de tu pedido #${p['id']} por ${dinero(p['total'])}. Pronto lo enviaremos.',
    'enviado' =>
      '$hola Tu pedido #${p['id']} ya fue enviado a: ${p['direccion']}.',
    'entregado' =>
      '$hola Tu pedido #${p['id']} fue entregado. ¡Gracias por tu compra! 🐶',
    _ => null,
  };
  if (texto == null || numero.isEmpty) return null;
  return Uri.https('wa.me', '/$numero', {'text': texto});
}

const meses = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

/// "2026-11-14T…" → "Noviembre 2026" (en hora local).
String mesDe(String creado) {
  final d = DateTime.parse(creado).toLocal();
  return '${meses[d.month - 1]} ${d.year}';
}

const estados = ['pendiente', 'pagado', 'enviado', 'entregado', 'cancelado'];
const iconoEstado = {
  'pendiente': Icons.schedule,
  'pagado': Icons.paid_outlined,
  'enviado': Icons.local_shipping_outlined,
  'entregado': Icons.task_alt,
  'cancelado': Icons.cancel_outlined,
};
Color colorEstado(String e, ColorScheme cs) => switch (e) {
  'pagado' => Colors.green.shade700,
  'enviado' => Colors.blue.shade700,
  'entregado' => Colors.teal.shade800,
  'cancelado' => cs.error,
  _ => Colors.orange.shade800,
};

class Pedidos extends StatefulWidget {
  const Pedidos({super.key, this.admin = false});
  final bool admin; // el admin ve los pedidos de todos (lo decide la RLS) y puede cambiar el estado
  @override
  State<Pedidos> createState() => _PedidosState();
}

class _PedidosState extends State<Pedidos> with WidgetsBindingObserver {
  late Future<List<Map<String, dynamic>>> lista = _cargar();

  Future<List<Map<String, dynamic>>> _cargar() {
    final q = sb
        .from('pedidos')
        .select('*, pedido_items(*), perfiles(nombre, telefono)');
    // El cliente no ve sus pedidos cancelados; el admin los ve todos.
    return (widget.admin ? q : q.neq('estado', 'cancelado')).order(
      'creado',
      ascending: false,
    );
  }

  Future<void> _cancelar(Map<String, dynamic> p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('¿Cancelar el pedido #${p['id']}?'),
        content: const Text(
          'El pedido se anulará y desaparecerá de tu lista. Esto no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('No'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(c).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await sb.rpc('cancelar_pedido', params: {'p_id': p['id']});
      if (mounted) aviso(context, 'Pedido #${p['id']} cancelado');
    } catch (e) {
      if (mounted) aviso(context, e);
    }
    _recargar();
  }

  void _recargar() => setState(() => lista = _cargar());

  // Al volver del navegador de pago, refresca para ver el estado nuevo.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _recargar();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.admin ? 'Todos los pedidos' : 'Mis pedidos'),
      actions: [
        if (widget.admin) ...[
          IconButton(
            tooltip: 'Exportar pedidos (respaldo)',
            icon: const Icon(Icons.download),
            onPressed: () async {
              try {
                final todos = await lista;
                if (mounted) await exportarRespaldo(context, 'pedidos', todos);
              } catch (e) {
                if (mounted) aviso(context, e);
              }
            },
          ),
          IconButton(
            tooltip: 'Importar pedidos (respaldo)',
            icon: const Icon(Icons.upload),
            onPressed: () async {
              final datos = await elegirRespaldo(context, 'pedidos');
              if (datos == null) return;
              try {
                final r = await sb.rpc(
                  'importar_pedidos',
                  params: {'datos': datos},
                );
                if (mounted) {
                  aviso(
                    context,
                    '${r['importados']} pedidos importados'
                    '${r['omitidos'] > 0 ? ' · ${r['omitidos']} omitidos (ya existían o el cliente no está registrado)' : ''}',
                  );
                }
              } catch (e) {
                if (mounted) aviso(context, e);
              }
              _recargar();
            },
          ),
        ],
        IconButton(
          tooltip: 'Actualizar',
          onPressed: _recargar,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder(
      future: lista,
      builder: (_, s) {
        if (s.hasError)
          return Center(
            child: Text('No se pudieron cargar los pedidos: ${s.error}'),
          );
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        if (s.data!.isEmpty)
          return vacio(Icons.receipt_long_outlined, 'Todavía no hay pedidos');
        // Vienen del más nuevo al más viejo: un título cada vez que cambia el mes.
        String? mesAnterior;
        return ListView(
          children: [
            for (final p in s.data!) ...[
              if (mesDe(p['creado']) != mesAnterior)
                _tituloMes(mesAnterior = mesDe(p['creado'])),
              _pedido(p),
            ],
          ],
        );
      },
    ),
  );

  /// El cliente escribe el número del comprobante de su transferencia; lo guarda la base (RPC).
  Future<void> _agregarComprobante(Map<String, dynamic> p) async {
    final ctl = TextEditingController(text: p['comprobante'] ?? '');
    final numero = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Pedido #${p['id']}: comprobante'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Número de comprobante',
            helperText: 'El número que te dio el banco al transferir',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, ctl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (numero == null || numero.isEmpty) return;
    try {
      await sb.rpc(
        'poner_comprobante',
        params: {'p_id': p['id'], 'p_numero': numero},
      );
      _recargar();
      if (mounted)
        aviso(
          context,
          'Comprobante guardado. Te avisaremos al confirmar el pago.',
        );
    } catch (err) {
      if (mounted) aviso(context, err);
    }
  }

  Widget _tituloMes(String mes) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
    child: Text(
      mes,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w900),
    ),
  );

  Widget _pedido(Map<String, dynamic> p) {
    final fecha = DateTime.parse(p['creado'])
        .toLocal()
        .toString()
        .substring(0, 16);
    final cliente = p['perfiles'];
    final cs = Theme.of(context).colorScheme;
    final color = colorEstado(p['estado'], cs);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(
              p['metodo'] == 'transferencia'
                  ? Icons.account_balance
                  : Icons.credit_card,
              color: color,
            ),
          ),
          title: Row(
            children: [
              Text(
                'Pedido #${p['id']}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                dinero(p['total']),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          subtitle: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${p['estado']}'.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
              Text(fecha),
              if (widget.admin)
                Text(
                  '${cliente['nombre']} · ${cliente['telefono']}'.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
            ],
          ),
          childrenPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final i in p['pedido_items'])
              Text(
                '${i['cantidad']} × ${i['nombre']} — ${dinero(i['precio'] * i['cantidad'])}',
              ),
            Text(
              'Entrega: ${widget.admin ? '${p['direccion']}'.toUpperCase() : p['direccion']}',
            ),
            if (p['comprobante'] != null)
              SelectableText(
                'Comprobante de transferencia: ${p['comprobante']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 8),
            if (p['estado'] == 'pendiente' && p['metodo'] == 'transferencia')
              OutlinedButton.icon(
                onPressed: () =>
                    mostrarTransferencia(context, p['id'], p['total']),
                icon: const Icon(Icons.account_balance),
                label: const Text('Ver datos de transferencia'),
              ),
            if (!widget.admin &&
                p['estado'] == 'pendiente' &&
                p['metodo'] == 'transferencia')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: FilledButton.icon(
                  onPressed: () => _agregarComprobante(p),
                  icon: const Icon(Icons.receipt_long),
                  label: Text(
                    p['comprobante'] == null
                        ? 'Agregar comprobante'
                        : 'Cambiar comprobante',
                  ),
                ),
              ),
            if (!widget.admin && p['estado'] == 'pendiente')
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => _cancelar(p),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancelar pedido'),
              ),
            if (widget.admin)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in estados)
                      ChoiceChip(
                        avatar: Icon(
                          iconoEstado[e],
                          size: 18,
                          color: p['estado'] == e
                              ? Colors.white
                              : colorEstado(e, cs),
                        ),
                        label: Text(e[0].toUpperCase() + e.substring(1)),
                        selected: p['estado'] == e,
                        showCheckmark: false,
                        shape: StadiumBorder(
                          side: BorderSide(color: colorEstado(e, cs)),
                        ),
                        selectedColor: colorEstado(e, cs),
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: p['estado'] == e
                              ? Colors.white
                              : colorEstado(e, cs),
                        ),
                        onSelected: p['estado'] == e
                            ? null
                            : (_) async {
                                try {
                                  await sb
                                      .from('pedidos')
                                      .update({'estado': e})
                                      .eq('id', p['id']);
                                  _recargar();
                                  final wa = avisoWhatsapp(p, e);
                                  if (wa != null) {
                                    await launchUrl(
                                      wa,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  } else if (![
                                        'pendiente',
                                        'cancelado',
                                      ].contains(e) &&
                                      mounted) {
                                    aviso(
                                      context,
                                      'El cliente no tiene teléfono: no se pudo avisar por WhatsApp',
                                    );
                                  }
                                } catch (err) {
                                  if (mounted) aviso(context, err);
                                }
                              },
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
