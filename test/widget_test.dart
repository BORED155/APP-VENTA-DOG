import 'package:app_venta_dog/carrito.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('carrito: suma, respeta stock y quita en cero', () {
    final collar = {'id': 1, 'nombre': 'Collar', 'precio': 7.5, 'stock': 2};
    final hueso = {'id': 2, 'nombre': 'Hueso', 'precio': 3, 'stock': 10};
    cambiarCantidad(collar, 1);
    cambiarCantidad(collar, 1);
    cambiarCantidad(collar, 1); // tope de stock
    cambiarCantidad(hueso, 1);
    expect(unidades(), 3);
    expect(total(), 18);
    expect(itemsParaPedido(), [
      {'producto_id': 1, 'cantidad': 2},
      {'producto_id': 2, 'cantidad': 1},
    ]);
    cambiarCantidad(hueso, -1);
    expect(carrito.value.containsKey(2), false);
  });
}
