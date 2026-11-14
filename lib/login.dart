import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'main.dart';

class Login extends StatefulWidget {
  const Login({super.key});
  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _form = GlobalKey<FormState>();
  final correo = TextEditingController(), clave = TextEditingController();
  final nombre = TextEditingController(), telefono = TextEditingController();
  final direccion = TextEditingController(), ciudad = TextEditingController();
  bool registro = false, ocupado = false;

  Future<void> _enviar() async {
    if (!_form.currentState!.validate()) return;
    if (clave.text.length < 6)
      return aviso(context, 'La contraseña necesita al menos 6 caracteres');
    setState(() => ocupado = true);
    try {
      if (registro) {
        final r = await sb.auth.signUp(
          email: correo.text.trim(),
          password: clave.text,
          data: {
            'nombre': nombre.text.trim(),
            'telefono': telefono.text.trim(),
            'direccion': direccion.text.trim(),
            'ciudad': ciudad.text.trim(),
          },
        );
        // Con confirmación por correo no hay sesión todavía: se pasa a "Entrar" con el correo ya escrito.
        if (r.session == null && mounted) {
          setState(() {
            registro = false;
            clave.clear();
          });
          await showDialog(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('¡Cuenta creada!'),
              content: Text(
                'Te enviamos un correo a ${correo.text.trim()}.\n\n'
                'Ábrelo, pulsa el enlace de confirmación y luego vuelve aquí y entra con tu contraseña.',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text('Entendido'),
                ),
              ],
            ),
          );
        }
      } else {
        await sb.auth.signInWithPassword(
          email: correo.text.trim(),
          password: clave.text,
        );
      }
    } on AuthException catch (e) {
      if (mounted) aviso(context, _traducir(e));
    } catch (e) {
      if (mounted) aviso(context, e);
    }
    if (mounted) setState(() => ocupado = false);
  }

  String _traducir(AuthException e) => switch (e.code) {
    'invalid_credentials' => 'Correo o contraseña incorrectos',
    'email_not_confirmed' => 'Aún no confirmas tu correo: revisa tu bandeja (y spam) y pulsa el enlace',
    'user_already_exists' =>
      'Ya existe una cuenta con ese correo: pulsa "Ya tengo cuenta"',
    'over_email_send_rate_limit' =>
      'Se enviaron demasiados correos; espera unos minutos',
    'weak_password' => 'La contraseña es muy débil',
    _ => e.message,
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: degradado),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.pets,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'APP VENTA DOG',
                      style: t.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      'Todo para tu mejor amigo',
                      style: t.textTheme.titleMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      elevation: 12,
                      shadowColor: Colors.black26,
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Form(
                          key: _form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SegmentedButton<bool>(
                                segments: const [
                                  ButtonSegment(
                                    value: false,
                                    label: Text('Entrar'),
                                    icon: Icon(Icons.login),
                                  ),
                                  ButtonSegment(
                                    value: true,
                                    label: Text('Registrarme'),
                                    icon: Icon(Icons.person_add_alt_1),
                                  ),
                                ],
                                selected: {registro},
                                onSelectionChanged: (v) =>
                                    setState(() => registro = v.first),
                              ),
                              const SizedBox(height: 20),
                              campo(
                                correo,
                                'Correo',
                                tipo: TextInputType.emailAddress,
                                icono: Icons.mail_outline,
                              ),
                              campo(
                                clave,
                                'Contraseña',
                                oculto: true,
                                icono: Icons.lock_outline,
                              ),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                                child: registro
                                    ? Column(
                                        children: [
                                          campo(
                                            nombre,
                                            'Nombre completo',
                                            icono: Icons.badge_outlined,
                                          ),
                                          campo(
                                            telefono,
                                            'Teléfono',
                                            tipo: TextInputType.phone,
                                            icono: Icons.phone_outlined,
                                          ),
                                          campo(
                                            direccion,
                                            'Dirección de entrega',
                                            icono: Icons.home_outlined,
                                          ),
                                          campo(
                                            ciudad,
                                            'Ciudad',
                                            icono: Icons.location_city_outlined,
                                          ),
                                        ],
                                      )
                                    : const SizedBox(width: double.infinity),
                              ),
                              const SizedBox(height: 6),
                              FilledButton(
                                onPressed: ocupado ? null : _enviar,
                                child: ocupado
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Text(
                                        registro ? 'Crear mi cuenta' : 'Entrar',
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
