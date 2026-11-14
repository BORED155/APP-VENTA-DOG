import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'main.dart';
import 'tienda.dart';

/// Pide a la función "pagar" el enlace de PayPhone y lo abre en el navegador
/// (PayPhone no permite su formulario dentro de la app).
Future<void> pagarPedido(BuildContext c, int id) async {
  try {
    final r = await sb.functions.invoke('pagar', body: {'pedido_id': id});
    await launchUrl(
      Uri.parse(r.data['url']),
      mode: LaunchMode.externalApplication,
    );
  } catch (e) {
    if (c.mounted) aviso(c, e);
  }
}

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
              'Cuando confirmemos el depósito, tu pedido pasará a "pagado" y lo enviaremos. '
              'Puedes volver a ver estos datos en Pedidos.',
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

const estados = ['pendiente', 'pagado', 'enviado', 'cancelado'];
const iconoEstado = {
  'pendiente': Icons.schedule,
  'pagado': Icons.paid_outlined,
  'enviado': Icons.local_shipping_outlined,
  'cancelado': Icons.cancel_outlined,
};
Color colorEstado(String e, ColorScheme cs) => switch (e) {
  'pagado' => Colors.green.shade700,
  'enviado' => Colors.blue.shade700,
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

  Future<List<Map<String, dynamic>>> _cargar() => sb
      .from('pedidos')
      .select('*, pedido_items(*), perfiles(nombre, telefono)')
      .order('creado', ascending: false);

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
        return ListView(children: [for (final p in s.data!) _pedido(p)]);
      },
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
              Text(
                '$fecha${widget.admin ? ' · ${cliente['nombre']} · ${cliente['telefono']}' : ''}',
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
            Text('Entrega: ${p['direccion']}'),
            const SizedBox(height: 8),
            if (p['estado'] == 'pendiente' && p['metodo'] == 'transferencia')
              OutlinedButton.icon(
                onPressed: () =>
                    mostrarTransferencia(context, p['id'], p['total']),
                icon: const Icon(Icons.account_balance),
                label: const Text('Ver datos de transferencia'),
              ),
            if (p['estado'] == 'pendiente' && p['metodo'] == 'tarjeta')
              FilledButton.icon(
                onPressed: () => pagarPedido(context, p['id']),
                icon: const Icon(Icons.credit_card),
                label: const Text('Pagar con tarjeta'),
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
