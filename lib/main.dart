import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login.dart';
import 'tienda.dart';

// Se pasan al compilar: --dart-define-from-file=config.json
const _url = String.fromEnvironment('SUPABASE_URL');
const _clave = String.fromEnvironment('SUPABASE_KEY');

SupabaseClient get sb => Supabase.instance.client;

// Paleta: turquesa (confianza, frescura) + amarillo "pelota de tenis" (juego, alegría).
const turquesa = Color(0xFF14A098);
const amarillo = Color(0xFFFFC93C);
const textoSobreAmarillo = Color(0xFF3D2E00);
const degradado = LinearGradient(
  colors: [Color(0xFF0E8C85), turquesa, Color(0xFF3CC8B0)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

ThemeData tema(Brightness b) {
  final cs = ColorScheme.fromSeed(
    seedColor: turquesa,
    brightness: b,
    primary: b == Brightness.light
        ? turquesa
        : null, // tonalSpot deja contenedores claros y legibles
    tertiary: amarillo,
    onTertiary: textoSobreAmarillo,
  );
  final base = ThemeData(colorScheme: cs, brightness: b);
  final redondo = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  );
  return base.copyWith(
    textTheme: GoogleFonts.nunitoTextTheme(base.textTheme),
    scaffoldBackgroundColor: b == Brightness.light
        ? const Color(0xFFF6FBFA)
        : cs.surface,
    badgeTheme: const BadgeThemeData(
      backgroundColor: amarillo,
      textColor: textoSobreAmarillo,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: GoogleFonts.nunito(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: cs.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: cs.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: redondo,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: redondo,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: redondo,
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: cs.surfaceContainerLowest,
      indicatorColor: cs.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(
        GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 12),
      ),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_url.isEmpty) {
    return runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Falta configurar Supabase: crea config.json (ver README) y vuelve a compilar.',
              ),
            ),
          ),
        ),
      ),
    );
  }
  await Supabase.initialize(url: _url, publishableKey: _clave);
  runApp(
    MaterialApp(
      title: 'APP VENTA DOG',
      debugShowCheckedModeBanner: false,
      theme: tema(Brightness.light),
      darkTheme: tema(Brightness.dark),
      home: StreamBuilder(
        stream: sb.auth.onAuthStateChange,
        builder: (_, _) =>
            sb.auth.currentSession == null ? const Login() : const Tienda(),
      ),
    ),
  );
}

void aviso(BuildContext c, Object e) {
  final t = switch (e) {
    PostgrestException(:final message) ||
    AuthException(:final message) => message,
    FunctionException(:final details, :final status) =>
      details is Map && details['error'] != null
          ? '${details['error']}'
          : 'No se pudo iniciar el pago (error $status)',
    _ => '$e',
  };
  ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(t)));
}

Widget campo(
  TextEditingController c,
  String etiqueta, {
  bool oculto = false,
  TextInputType? tipo,
  bool requerido = true,
  int lineas = 1,
  IconData? icono,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 14),
  child: TextFormField(
    controller: c,
    obscureText: oculto,
    keyboardType: tipo,
    maxLines: lineas,
    decoration: InputDecoration(
      labelText: etiqueta,
      prefixIcon: icono == null ? null : Icon(icono),
    ),
    validator: (v) =>
        requerido && (v ?? '').trim().isEmpty ? 'Obligatorio' : null,
  ),
);

/// Estado vacío con icono grande, para listas sin datos.
Widget vacio(IconData icono, String texto) => Builder(
  builder: (c) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Theme.of(c).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icono,
              size: 56,
              color: Theme.of(c).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: Theme.of(c).textTheme.titleMedium,
          ),
        ],
      ),
    ),
  ),
);
