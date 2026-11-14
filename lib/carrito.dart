import 'package:flutter/foundation.dart';

typedef Linea = ({Map<String, dynamic> producto, int cantidad});

/// producto_id -> línea. shortcut: vive en memoria (se vacía al cerrar la app); guardarlo en la base si lo piden.
final carrito = ValueNotifier<Map<int, Linea>>({});

void cambiarCantidad(Map<String, dynamic> producto, int delta) {
  final id = producto['id'] as int;
  final nueva = ((carrito.value[id]?.cantidad ?? 0) + delta).clamp(
    0,
    producto['stock'] as int,
  );
  final m = {...carrito.value};
  if (nueva == 0) {
    m.remove(id);
  } else {
    m[id] = (producto: producto, cantidad: nueva);
  }
  carrito.value = m;
}

int unidades() => carrito.value.values.fold(0, (s, l) => s + l.cantidad);

/// Solo informativo: el total que se cobra lo calcula la base de datos.
num total() => carrito.value.values.fold<num>(
  0,
  (s, l) => s + (l.producto['precio'] as num) * l.cantidad,
);

List<Map<String, int>> itemsParaPedido() => [
  for (final e in carrito.value.entries)
    {'producto_id': e.key, 'cantidad': e.value.cantidad},
];
