import 'package:material_ui/material_ui.dart';

import 'carrito.dart';
import 'main.dart';

class Perfil extends StatefulWidget {
  const Perfil({super.key});
  @override
  State<Perfil> createState() => _PerfilState();
}

class _PerfilState extends State<Perfil> {
  final _form = GlobalKey<FormState>();
  final c = {
    for (final k in ['nombre', 'telefono', 'direccion', 'ciudad'])
      k: TextEditingController(),
  };
  String get uid => sb.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    sb.from('perfiles').select().eq('id', uid).single().then((p) {
      for (final e in c.entries) {
        e.value.text = p[e.key] ?? '';
      }
    }, onError: (e) => mounted ? aviso(context, e) : null);
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    try {
      await sb
          .from('perfiles')
          .update({for (final e in c.entries) e.key: e.value.text.trim()})
          .eq('id', uid);
      if (mounted) aviso(context, 'Datos guardados ✓');
    } catch (e) {
      if (mounted) aviso(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: degradado,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, size: 48, color: Colors.white),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                sb.auth.currentUser!.email ?? '',
                style: t.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 24),
            campo(c['nombre']!, 'Nombre completo', icono: Icons.badge_outlined),
            campo(
              c['telefono']!,
              'Teléfono',
              tipo: TextInputType.phone,
              icono: Icons.phone_outlined,
            ),
            campo(
              c['direccion']!,
              'Dirección de entrega',
              icono: Icons.home_outlined,
            ),
            campo(c['ciudad']!, 'Ciudad', icono: Icons.location_city_outlined),
            const SizedBox(height: 6),
            FilledButton.icon(
              onPressed: _guardar,
              icon: const Icon(Icons.check),
              label: const Text('Guardar cambios'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                carrito.value = {};
                sb.auth.signOut();
              },
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}
