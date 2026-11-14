// Página a la que lleva el enlace de confirmación del correo (Site URL de Auth).
// Desplegada desde el panel con "Verify JWT" desactivado (es pública).
Deno.serve(() =>
  new Response("¡Correo confirmado! Ya puedes cerrar esta página y entrar en APP VENTA DOG con tu correo y contraseña.", {
    headers: { "Content-Type": "text/plain; charset=utf-8" },
  }));
