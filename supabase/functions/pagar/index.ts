// Crea el cobro en PayPhone para un pedido pendiente y devuelve la URL de pago con tarjeta.
import { createClient } from "npm:@supabase/supabase-js@2";

const PAYPHONE = "https://pay.payphonetodoesposible.com/api/button";
const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  const { pedido_id } = await req.json().catch(() => ({}));
  // Cliente con el token del usuario: RLS garantiza que solo ve sus propios pedidos.
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
  });
  const { data: p } = await sb.from("pedidos").select("id,total,estado").eq("id", pedido_id).maybeSingle();
  if (!p || p.estado !== "pendiente") return json({ error: "Pedido no válido o ya pagado" }, 400);

  const centavos = Math.round(Number(p.total) * 100);
  // shortcut: todo el monto va como "sin impuesto"; si hay que desglosar IVA, separar amountWithTax/tax.
  const r = await fetch(`${PAYPHONE}/Prepare`, {
    method: "POST",
    headers: { Authorization: `Bearer ${Deno.env.get("PAYPHONE_TOKEN")}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      amount: centavos,
      amountWithoutTax: centavos,
      currency: "USD",
      clientTransactionId: `${p.id}-${Date.now()}`, // único por intento; confirmar lee el pedido del prefijo
      reference: `APP VENTA DOG pedido ${p.id}`,
      storeId: Deno.env.get("PAYPHONE_STORE_ID") || undefined,
      responseUrl: `${Deno.env.get("SUPABASE_URL")}/functions/v1/confirmar`,
    }),
  });
  const d = await r.json().catch(() => ({}));
  if (!r.ok || !d.payWithCard) return json({ error: d.message ?? "PayPhone no respondió" }, 502);
  return json({ url: d.payWithCard });
});
