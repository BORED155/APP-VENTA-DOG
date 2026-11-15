import 'package:app_venta_dog/carrito.dart';
import 'package:app_venta_dog/respaldo.dart';
import 'package:app_venta_dog/pedidos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  pruebasWhatsapp();
  pruebasRespaldo();
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

// Fuera de main() no corre: se registra abajo.
void pruebasWhatsapp() {
  test(
    'mes del pedido',
    () => expect(mesDe('2026-11-14T15:00:00Z'), 'Noviembre 2026'),
  );
  test('aviso por WhatsApp: número de Ecuador y mensaje por estado', () {
    expect(numeroWhatsapp('099 123-4567'), '593991234567');
    expect(numeroWhatsapp('+593 99 123 4567'), '593991234567');
    final p = {
      'id': 7,
      'total': 12.5,
      'direccion': 'Av. 1, Quito',
      'perfiles': {'nombre': 'Ana', 'telefono': '0991234567'},
    };
    final u = avisoWhatsapp(p, 'pagado')!;
    expect(u.host, 'wa.me');
    expect(u.path, '/593991234567');
    expect(u.queryParameters['text'], contains('pago de tu pedido #7'));
    expect(
      avisoWhatsapp(p, 'enviado')!.queryParameters['text'],
      contains('Av. 1, Quito'),
    );
    expect(avisoWhatsapp(p, 'cancelado'), isNull);
    expect(
      avisoWhatsapp(p, 'entregado')!.queryParameters['text'],
      contains('entregado'),
    );
    expect(avisoWhatsapp(p, 'pendiente'), isNull);
    expect(
      avisoWhatsapp({
        ...p,
        'perfiles': {'nombre': 'Ana', 'telefono': ''},
      }, 'pagado'),
      isNull,
    );
  });
}

void pruebasRespaldo() {
  test('respaldo: ida y vuelta, y rechaza otro tipo', () {
    final datos = [
      {'id': 1, 'nombre': 'Collar ñandú', 'precio': 7.5},
    ];
    expect(leerRespaldo(armarRespaldo('productos', datos), 'productos'), datos);
    expect(
      () => leerRespaldo(armarRespaldo('pedidos', []), 'productos'),
      throwsFormatException,
    );
    expect(
      () => leerRespaldo('no es json', 'productos'),
      throwsFormatException,
    );
  });
}
