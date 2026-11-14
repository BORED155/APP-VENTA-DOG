import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import 'main.dart';

/// Respaldo de productos o pedidos en un archivo .json: {"tipo", "exportado", "datos": [...]}.
String armarRespaldo(String tipo, List<dynamic> datos) =>
    const JsonEncoder.withIndent('  ').convert({
      'tipo': tipo,
      'exportado': DateTime.now().toIso8601String(),
      'datos': datos,
    });

/// Lee un respaldo y devuelve sus datos; falla si el archivo no es de ese tipo.
List<dynamic> leerRespaldo(String texto, String tipo) {
  final Object? j;
  try {
    j = jsonDecode(texto);
  } on FormatException {
    throw const FormatException('El archivo no es un respaldo válido');
  }
  if (j is! Map || j['datos'] is! List) {
    throw const FormatException('El archivo no es un respaldo válido');
  }
  if (j['tipo'] != tipo) {
    throw FormatException(
      'Ese archivo es un respaldo de ${j['tipo']}, no de $tipo',
    );
  }
  return j['datos'];
}

Future<void> exportarRespaldo(
  BuildContext c,
  String tipo,
  List<dynamic> datos,
) async {
  try {
    final hoy = DateTime.now().toIso8601String().substring(0, 10);
    final uri = await FilePicker.saveFile(
      fileName: '$tipo-$hoy.json',
      bytes: utf8.encode(armarRespaldo(tipo, datos)),
      mimeType: 'application/json',
      dialogTitle: 'Guardar respaldo de $tipo',
    );
    if (uri != null && c.mounted) {
      aviso(c, 'Respaldo guardado: ${datos.length} $tipo');
    }
  } catch (e) {
    if (c.mounted) aviso(c, e);
  }
}

/// Pide el archivo, lo valida y pregunta antes de cargarlo. Devuelve los datos o null si se canceló.
Future<List<dynamic>?> elegirRespaldo(BuildContext c, String tipo) async {
  try {
    final f = await FilePicker.pickFile(
      dialogTitle: 'Abrir respaldo de $tipo',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (f == null) return null;
    final datos = leerRespaldo(utf8.decode(await f.readAsBytes()), tipo);
    if (!c.mounted) return null;
    final ok = await showDialog<bool>(
      context: c,
      builder: (d) => AlertDialog(
        title: Text('¿Importar ${datos.length} $tipo?'),
        content: Text(
          tipo == 'productos'
              ? 'Los productos que ya existen (mismo número) se reemplazan con los del archivo; '
                    'los demás se agregan.'
              : 'Se agregan los pedidos que no existen. Los que ya están no se tocan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Importar'),
          ),
        ],
      ),
    );
    return ok == true ? datos : null;
  } catch (e) {
    if (c.mounted) aviso(c, e is FormatException ? e.message : e);
    return null;
  }
}
