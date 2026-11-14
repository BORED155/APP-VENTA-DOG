# APP VENTA DOG

Tienda virtual de artículos para perros. Android y Mac (Flutter) + Supabase (cuentas, base de datos, fotos)
+ pago por transferencia bancaria (el pago con tarjeta PayPhone se quitó el 2026-11-14;
las funciones `supabase/functions/pagar` y `confirmar` siguen en el repo por si se vuelve a activar).

- Registro obligatorio: correo, contraseña, nombre, teléfono, dirección, ciudad (editable en *Mi perfil*).
- Catálogo con fotos, carrito, *Pagar por transferencia* + número de comprobante, *Mis pedidos*.
- Cuenta administradora: *Administrar productos* (crear/editar, foto, precio, stock, ocultar) y ve
  **todos** los pedidos con el cliente y su teléfono, y cambia el estado (pendiente → pagado → enviado / cancelado).
- Seguridad en la base (RLS): un cliente solo ve sus pedidos; solo el admin toca productos; el precio y el total
  se calculan en la base, nunca se confía en lo que manda el teléfono; el pedido solo pasa a *pagado* si PayPhone lo confirma.

## Puesta en marcha (una sola vez)

1. **Supabase**: crea un proyecto en supabase.com → *SQL Editor* → pega `supabase/schema.sql` → *Run*.
2. Copia `config.ejemplo.json` a `config.json` y pon la *Project URL* y la *Publishable key*
   (Settings → API Keys).
3. **PayPhone**: en tu cuenta de comercio (PayPhone Developer) crea la app tipo *Web*, copia el **token** y el
   **storeId**, y registra como dominio/URL de respuesta: `https://TU-PROYECTO.supabase.co/functions/v1/confirmar`.
4. Sube las funciones de pago (necesita la CLI: `npm i -g supabase`):
   ```
   supabase login
   supabase link --project-ref TU-PROYECTO
   supabase secrets set PAYPHONE_TOKEN=... PAYPHONE_STORE_ID=...
   supabase functions deploy pagar
   supabase functions deploy confirmar --no-verify-jwt
   ```
5. Abre la app, regístrate con tu correo y conviértete en admin ejecutando en el SQL Editor la línea comentada
   al final de `schema.sql`. Cierra sesión y vuelve a entrar.

## Compilar

```
export PATH=$HOME/flutter/bin:$PATH ANDROID_HOME=$HOME/Android/Sdk
flutter test
flutter build apk --release --dart-define-from-file=config.json   # → build/app/outputs/flutter-apk/app-release.apk
flutter run --dart-define-from-file=config.json                   # en un teléfono conectado por USB
```

**Mac**: Apple solo permite compilar en una Mac. Opciones: en una Mac con Xcode
`flutter build macos --release --dart-define-from-file=config.json`, o subir el repo a GitHub, poner los secretos
`SUPABASE_URL` y `SUPABASE_KEY` y lanzar el flujo *compilar* (Actions): deja el APK y el zip de Mac para descargar.
La app de Mac sale sin firmar: la primera vez se abre con clic derecho → Abrir.

## Pendiente / decisiones

- El monto se envía a PayPhone sin desglose de IVA (`supabase/functions/pagar/index.ts`).
- El carrito vive en memoria: si se cierra la app, se vacía (los pedidos sí quedan guardados).
- El stock se descuenta al confirmarse el pago, no al crear el pedido.
- Para Google Play hace falta firmar con tu propia llave (ahora el release usa la llave de depuración).
