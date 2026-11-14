// PayPhone redirige aquí el navegador tras el pago (?id=&clientTransactionId=).
// Hay que confirmar en menos de 5 minutos o PayPhone reversa el cobro.
// Se despliega con --no-verify-jwt: es pública, pero no confía en la URL, pregunta a PayPhone.
import { createClient } from "npm:@supabase/supabase-js@2";

const texto = (t: string) => new Response(t, { headers: { "Content-Type": "text/plain; charset=utf-8" } });

Deno.serve(async (req) => {
  const q = new URL(req.url).searchParams;
  const tx = q.get("clientTransactionId") ?? "";
  const r = await fetch("https://pay.payphonetodoesposible.com/api/button/V2/Confirm", {
    method: "POST",
    headers: { Authorization: `Bearer ${Deno.env.get("PAYPHONE_TOKEN")}`, "Content-Type": "application/json" },
    body: JSON.stringify({ id: Number(q.get("id")), clientTxId: tx }),
  });
  const c = await r.json().catch(() => ({}));
  if (!r.ok || c.statusCode !== 3 || c.clientTransactionId !== tx) {
    return texto("El pago no fue aprobado. Vuelve a la app e inténtalo otra vez desde Mis pedidos.");
  }

  const pedidoId = Number(tx.split("-")[0]);
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data: p } = await sb.from("pedidos").select("total").eq("id", pedidoId).maybeSingle();
  if (!p || Math.round(Number(p.total) * 100) !== c.amount) {
    return texto(`Pago recibido (autorización ${c.authorizationCode}) pero no coincide con el pedido. Contacta a la tienda.`);
  }
  const { error } = await sb.rpc("marcar_pagado", { p_id: pedidoId });
  if (error) return texto(`Pago aprobado (autorización ${c.authorizationCode}) pero no se pudo registrar. Contacta a la tienda.`);
  return texto(`¡Pago aprobado! Pedido #${pedidoId}. Ya puedes volver a APP VENTA DOG.`);
});
