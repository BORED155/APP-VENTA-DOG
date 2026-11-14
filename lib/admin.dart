import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'main.dart';
import 'tienda.dart';

/// Solo visible para cuentas con es_admin; la base rechaza igual a cualquier otro.
class AdminProductos extends StatefulWidget {
  const AdminProductos({super.key});
  @override
  State<AdminProductos> createState() => _AdminProductosState();
}

class _AdminProductosState extends State<AdminProductos> {
  late Future<List<Map<String, dynamic>>> lista = _cargar();
  Future<List<Map<String, dynamic>>> _cargar() => sb
      .from('productos')
      .select()
      .order('categoria', ascending: true)
      .order('nombre', ascending: true);

  Future<void> _editar([Map<String, dynamic>? p]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FormProducto(p)),
    );
    setState(() => lista = _cargar());
  }

  Future<bool?> _preguntar(String titulo, String texto, String accion) =>
      showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(titulo),
          content: Text(texto),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(c).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(c, true),
              child: Text(accion),
            ),
          ],
        ),
      );

  Future<void> _eliminar(Map<String, dynamic> p) async {
    final ok = await _preguntar(
      '¿Eliminar producto?',
      'Se borrará "${p['nombre']}" de la tienda. Esto no se puede deshacer.',
      'Eliminar',
    );
    if (ok != true) return;
    try {
      // Pedidos cancelados o enviados no impiden borrar: cada línea guarda su nombre y precio.
      // Los pendientes o pagados aún hay que despacharlos: ahí solo se ofrece ocultar.
      final enCurso = await sb
          .from('pedido_items')
          .select('pedido_id, pedidos!inner(estado)')
          .eq('producto_id', p['id'])
          .inFilter('pedidos.estado', ['pendiente', 'pagado']);
      if (enCurso.isEmpty) {
        try {
          await sb.from('productos').delete().eq('id', p['id']);
          if (mounted) aviso(context, '"${p['nombre']}" eliminado');
          setState(() => lista = _cargar());
          return;
        } on PostgrestException catch (e) {
          // 23503 = la base aún no tiene la actualización del 2026-11-14 de schema.sql.
          if (e.code != '23503') rethrow;
          if (mounted) {
            aviso(context, 'Falta aplicar en Supabase la actualización del 2026-11-14 (schema.sql)');
          }
          return;
        }
      }
      if (!mounted) return;
      final ocultar = await _preguntar(
        'No se puede eliminar',
        '"${p['nombre']}" está en ${enCurso.length} pedido(s) pendiente(s) o pagado(s) que aún '
            'no se han enviado. Cuando estén enviados o cancelados podrás eliminarlo. '
            '¿Quieres ocultarlo ya para que no aparezca más en la tienda?',
        'Ocultar',
      );
      if (ocultar == true) {
        await sb.from('productos').update({'activo': false}).eq('id', p['id']);
        if (mounted) aviso(context, '"${p['nombre']}" oculto de la tienda');
      }
    } catch (e) {
      if (mounted) aviso(context, e);
    }
    setState(() => lista = _cargar());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Administrar productos')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _editar,
      icon: const Icon(Icons.add),
      label: const Text('Nuevo producto'),
    ),
    body: FutureBuilder(
      future: lista,
      builder: (_, s) {
        if (s.hasError) return Center(child: Text('${s.error}'));
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        return ListView(
          padding: const EdgeInsets.only(bottom: 80),
          children: [
            for (final p in s.data!)
              ListTile(
                leading: SizedBox(width: 56, child: foto(p, alto: 56)),
                title: Text(p['nombre']),
                subtitle: Text(
                  '${p['categoria']} · ${dinero(p['precio'])} · stock ${p['stock']}${p['activo'] ? '' : ' · OCULTO'}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Editar',
                      onPressed: () => _editar(p),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Eliminar',
                      onPressed: () => _eliminar(p),
                      icon: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
                onTap: () => _editar(p),
              ),
          ],
        );
      },
    ),
  );
}

class FormProducto extends StatefulWidget {
  const FormProducto(this.p, {super.key});
  final Map<String, dynamic>? p;
  @override
  State<FormProducto> createState() => _FormProductoState();
}

class _FormProductoState extends State<FormProducto> {
  final _form = GlobalKey<FormState>();
  late final p = widget.p ?? {};
  late final nombre = TextEditingController(text: p['nombre']);
  late final descripcion = TextEditingController(text: p['descripcion']);
  late final precio = TextEditingController(text: p['precio']?.toString());
  late final stock = TextEditingController(text: '${p['stock'] ?? 0}');
  late final categoria = TextEditingController(text: p['categoria'] ?? 'Otros');
  late bool activo = p['activo'] ?? true;
  XFile? imagen;
  bool ocupado = false;

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    final pr = double.tryParse(precio.text.replaceAll(',', '.'));
    final st = int.tryParse(stock.text);
    if (pr == null || pr <= 0 || st == null || st < 0)
      return aviso(context, 'Revisa precio y stock');
    setState(() => ocupado = true);
    try {
      var url = p['imagen_url'];
      if (imagen != null) {
        // shortcut: la foto anterior queda en el bucket; borrarla si el espacio llega a importar.
        final ruta = '${DateTime.now().millisecondsSinceEpoch}-${imagen!.name}';
        await sb.storage
            .from('productos')
            .uploadBinary(
              ruta,
              await imagen!.readAsBytes(),
              fileOptions: FileOptions(
                contentType: imagen!.mimeType ?? 'image/jpeg',
              ),
            );
        url = sb.storage.from('productos').getPublicUrl(ruta);
      }
      final fila = {
        'nombre': nombre.text.trim(),
        'descripcion': descripcion.text.trim(),
        'precio': pr,
        'stock': st,
        'categoria': categoria.text.trim(),
        'activo': activo,
        'imagen_url': url,
      };
      if (p['id'] == null) {
        await sb.from('productos').insert(fila);
      } else {
        await sb.from('productos').update(fila).eq('id', p['id']);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) aviso(context, e);
    }
    if (mounted) setState(() => ocupado = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(p['id'] == null ? 'Nuevo producto' : 'Editar producto'),
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OutlinedButton.icon(
            onPressed: () async {
              final x = await ImagePicker().pickImage(
                source: ImageSource.gallery,
                maxWidth: 1200,
                imageQuality: 85,
              );
              if (x != null) setState(() => imagen = x);
            },
            icon: const Icon(Icons.photo),
            label: Text(
              imagen?.name ??
                  (p['imagen_url'] == null ? 'Elegir foto' : 'Cambiar foto'),
            ),
          ),
          const SizedBox(height: 12),
          campo(nombre, 'Nombre'),
          // Escribir exactamente igual que una categoría existente para que se agrupe con ella.
          campo(
            categoria,
            'Categoría (ej. Vacunas, Collares Dominal)',
            icono: Icons.category_outlined,
          ),
          campo(descripcion, 'Descripción', requerido: false, lineas: 3),
          campo(
            precio,
            'Precio (USD)',
            tipo: const TextInputType.numberWithOptions(decimal: true),
          ),
          campo(stock, 'Stock (unidades)', tipo: TextInputType.number),
          // No se borran productos (pueden estar en pedidos viejos): se ocultan.
          SwitchListTile(
            title: const Text('Visible en la tienda'),
            value: activo,
            onChanged: (v) => setState(() => activo = v),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: ocupado ? null : _guardar,
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
}
