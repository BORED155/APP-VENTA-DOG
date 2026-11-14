"""Genera productos.sql y las fotos (jpg) a partir del CATÁLOGO 2026-09-23.pdf.

Uso: python3 generar.py <carpeta con imágenes de pdfimages -png -p> <carpeta de salida para jpg>
Precio = P.V.P.; si el catálogo solo trae un precio, se usa ese. Stock inicial 10.
"""
import subprocess
import sys
from pathlib import Path

URL = "https://nsdngcbsjaxnbgociksi.supabase.co/storage/v1/object/public/productos/"

NEO = "Neo 1 · Antisépticos"
NUT = "Nutritoys · Alimento y suplementos"
VAC = "Vacunas"
SUT = "Suturas"
BIO = "Tests Bioguard"
RUI = "Ruiland · Suplementos"
LIF = "Life · Medicamentos"
DOM = "Collares Dominal"
VAR = "Varios"

neo1 = ("Antiséptico avanzado de grado médico a base de Ácido Hipocloroso (HOCl) para piel, mucosas y boca. "
        "Multiespecie (perros, gatos, aves, reptiles), hipoalergénico, no irritante y no tóxico en caso de ingestión. "
        "Usos: heridas, quemaduras y úlceras; infecciones por hongos, bacterias y virus; mal aliento, sarro y gingivitis. "
        "Listo para usar: rociar sobre la piel o en la boca 2 veces al día. Conservar vertical, en lugar fresco y sin sol directo.")
enzy = ("Detergente multienzimático tipo 5 para instrumental clínico, odontológico y veterinario. Degrada sangre, proteínas, "
        "tejidos y mucosas; pH neutro, biodegradable y de baja espuma. Uso: 8 ml por litro de agua, sumergir 5 minutos, "
        "cepillar y enjuagar. No mezclar con cloro ni otros detergentes.")
vac = "Promoción: 1 jeringuilla gratis por cada vacuna."
ruiland = "Suplemento nutricional de uso veterinario, frasco de 60 tabletas. Promoción 6+1 o 12+2."
life = "Promoción 6+1 o 12+2."
bongo = ("Antiparasitario interno con Omega 3 para perros y gatos: controla gusanos redondos y planos (incluido Echinococcus). "
         "Pamoato de pirantel 75 mg, praziquantel 25 mg y aceite de hígado de bacalao 40 mg. " + life)
dominal = ("Collar pulguicida y garrapaticida de liberación controlada, con suave aroma. Elimina huevos y larvas del ambiente, "
           "resiste lluvia y sol, con sistema anti-ahorque. Protección 12 semanas. No usar en hembras preñadas ni en "
           "cachorros o gatitos menores de 2 meses.")
galleta = ("Galletas horneadas de grado humano con prebióticos y probióticos: mejoran la digestión y refuerzan las defensas. "
           "Harina de trigo y maíz, salvado, miel, sabores naturales, vitaminas y minerales.")
michiko = "Golosina húmeda y cremosa para gatos, sin colorantes ni conservantes, con vitamina E."
filete = ("Snack natural de textura húmeda y tierna, 100% proteína, rico en Omega 3 y 6, sin conservantes ni colorantes. "
          "25 g. Apto para perros según criterio del veterinario.")

# (nombre, categoría, precio, imagen, descripción)
P = [
    ("Neo 1 antiséptico 130 ml", NEO, 7.59, "i-004-004", neo1 + " Promoción: 3+2, 6+4 +3% de descuento, 9+6 +5% de descuento."),
    ("Neo 1 antiséptico 1 litro", NEO, 22.00, "i-004-004", neo1 + " Promoción: 3% de descuento adicional desde 6 unidades."),
    ("ClorOne Vet desinfectante 2 litros", NEO, 6.90, "i-005-005",
     "Desinfectante de alto nivel con Ácido Hipocloroso (HOCl), seguro en presencia de mascotas y personas. Para quirófanos, "
     "instrumental, estética animal y el hogar (juguetes, camas, platos). Rociar, dejar actuar 1 a 5 minutos y dejar secar; "
     "no requiere enjuague. Apto para nebulización en frío."),
    ("EnzyOne detergente enzimático 1 litro", NEO, 16.56, "i-006-006", enzy),
    ("EnzyOne detergente enzimático 1 galón", NEO, 57.50, "i-006-007", enzy),

    ("Simbyos SP perro / gato", NUT, 9.94, "i-008-008",
     "Prebiótico simbiótico con Bacillus subtilis: regenera la microbiota intestinal, mejora la absorción de nutrientes y "
     "previene diarreas y alergias. Caja con 7 sobres de 5 g. Mezclar 1 sobre con agua o con el alimento; 1 tratamiento de 7 días al mes."),
    ("Simbyos AID perro / gato", NUT, 9.94, "i-008-010",
     "Probiótico + prebiótico + Yucca schidigera: reduce el mal olor de las heces y mejora la asimilación de nutrientes. "
     "Caja con 7 sobres de 5 g. Mezclar con el alimento; 1 tratamiento de 7 días al mes."),
    ("DQ Patox protector hepático perro / gato", NUT, 11.60, "i-009-012",
     "Protector hepático con silimarina: regenera y protege el hígado, mejora la digestión de dietas grasas. "
     "Caja con 7 sobres de 5 g. Preventivo: 1 sobre semanal. Curativo: 1 sobre diario por 7 días."),
    ("Alimento húmedo para perro 100 g", NUT, 2.37, "i-010-016",
     "Alimento completo de alta palatabilidad, rico en proteína, con prebióticos, vitaminas, minerales y Omega 3, 6 y 9. "
     "Carne de res, huevo y vegetales (arroz, arveja, zanahoria)."),
    ("Alimento húmedo para gato 100 g", NUT, 2.65, "i-009-013",
     "Alimento completo y balanceado de hígado de pollo con prebióticos y Omega 3, 6 y 9. Mejora la hidratación y estimula el apetito."),
    ("Galletas para perro 150 g mini surtido", NUT, 2.96, "i-010-014", galleta),
    ("Galletas para perro 250 g (surtido, avena, mango o zanahoria)", NUT, 4.62, "i-010-015", galleta),
    ("Michiko snack semanario (7 sachets)", NUT, 8.57, "i-011-018",
     michiko + " Un sabor para cada día: salmón, pollo, atún, pescados de mar con atún, pollo y queso, atún con camarón y pollo con pato. 7 sachets de 14 g."),
    ("Michiko snack 4 sachets", NUT, 5.09, "i-011-019",
     michiko + " Sabores: pollo, atún, salmón o atún y salmón. 4 sachets de 14 g."),
    ("Michiko filete de pollo / atún", NUT, 3.20, "i-012-024", filete),
    ("Michiko filete de salmón", NUT, 3.43, "i-012-025", filete),

    ("Vacuna Vibix Parvo", VAC, 2.76, "i-014-026",
     "Vacuna viva modificada contra parvovirus canino, para perros desde la 6.ª semana. Precio por unidad; caja de 10: $27.60. " + vac),
    ("Vacuna Vibix C Puppy Advanced", VAC, 5.40, "i-014-027",
     "Vacuna viva modificada contra moquillo y parvovirus canino (2a, 2b, 2c), para cachorros desde las 6 semanas. "
     "Precio por unidad; caja de 10: $54.00. " + vac),
    ("Vacuna Vibix C4", VAC, 3.76, "i-015-028",
     "Vacuna viva modificada contra moquillo, adenovirus tipo 2, parvovirus y parainfluenza canina. "
     "Precio por unidad; caja de 10: $37.60. " + vac),
    ("Vacuna Vibix C5", VAC, 4.32, "i-015-029",
     "Vacuna contra moquillo, adenovirus tipo 2, parvovirus, parainfluenza y leptospira (4 serovares). "
     "Precio por unidad; caja de 10: $43.20. " + vac),
    ("Vacuna Vibix C6R", VAC, 6.48, "i-016-030",
     "Vacuna contra moquillo, hepatitis, parvovirus, parainfluenza, leptospira (4 serovares) y rabia. "
     "Precio por unidad; caja de 10: $64.80. " + vac),
    ("Vacuna Vibix Rabia", VAC, 2.60, "i-016-031",
     "Vacuna inactivada contra la rabia para perros y gatos desde las 12 semanas. Precio por unidad; caja de 10: $26.00. " + vac),
    ("Vacuna Vibix F3 (gatos)", VAC, 4.44, "i-017-032",
     "Vacuna inactivada contra panleucopenia, rinotraqueitis (herpesvirus) y calicivirus felino, para gatos desde la 8.ª semana. "
     "Precio por unidad; caja de 10: $44.40. " + vac),
    ("Vacuna Vibix F3+R (gatos)", VAC, 6.36, "i-017-033",
     "Vacuna inactivada contra panleucopenia, rinotraqueitis, calicivirus y rabia felina. Precio por unidad; caja de 10: $63.60. " + vac),
    ("Vacuna Bronchicine CAe", VAC, 3.99, "i-018-034",
     "Vacuna para perros contra la tos de las perreras (Bordetella). Precio por unidad; caja de 50: $199.50."),
    ("Vacuna Felocell FeLV (gatos)", VAC, 9.98, "i-018-035",
     "Vacuna preventiva contra la leucemia viral felina. Precio por unidad; caja de 25: $249.50."),

    ("Sutura ácido poliglicólico", SUT, 2.00, "i-019-036", "Sutura absorbible. Precio por unidad, cualquier calibre; caja de 12: $24.00."),
    ("Sutura polidioxanona", SUT, 2.08, "i-019-037", "Sutura absorbible. Precio por unidad, cualquier calibre; caja de 12: $24.96."),
    ("Sutura nylon", SUT, 1.68, "i-019-038", "Sutura no absorbible. Precio por unidad, cualquier calibre; caja de 12: $20.16."),

    ("Test Distemper Ag (CDV)", BIO, 6.95, "i-021-040", "Test rápido Bioguard de antígeno de moquillo canino. Precio por unidad; caja de 10: $59.50."),
    ("Test Parvovirus Ag / Coronavirus Ag", BIO, 7.40, "i-021-039", "Test rápido Bioguard de parvovirus y coronavirus canino. Precio por unidad; caja de 10: $64.00."),
    ("Test 4X (gusano del corazón, Lyme, Ehrlichia, Anaplasma)", BIO, 14.50, "i-022-041",
     "Test rápido Bioguard: Gusano del corazón Ag, Lyme Ab, Ehrlichia canis Ab y Anaplasma Ab. Precio por unidad; caja de 10: $135.00."),
    ("Test 4LX (gusano del corazón, Leishmania, Ehrlichia, Anaplasma)", BIO, 15.50, "i-022-042",
     "Test rápido Bioguard: Gusano del corazón Ag, Leishmania Ab, Ehrlichia canis Ab y Anaplasma Ab. Precio por unidad; caja de 10: $145.00."),
    ("Test Toxoplasma IgM / IgG", BIO, 9.20, "i-023-043", "Test rápido Bioguard de anticuerpos de toxoplasma. Precio por unidad; caja de 10: $82.00."),
    ("Test FeLV Ag / FIV Ab (leucemia y sida felino)", BIO, 9.95, "i-023-044", "Test rápido Bioguard para gatos. Precio por unidad; caja de 10: $89.50."),
    ("Kit tipificación sanguínea felina", BIO, 20.80, "i-024-045", "Kit Bioguard para tipificar sangre de gatos. Precio por unidad; caja de 5: $99.00."),

    ("Ruiland Artroflex 60 tabletas", RUI, 30.00, "i-026-047",
     "Antiinflamatorio, analgésico y condroprotector de origen natural; regenerador osteoarticular. Para problemas del aparato "
     "locomotor, cojera y molestias articulares en perros jóvenes, adultos y mayores. " + ruiland),
    ("Ruiland CAP 60 tabletas", RUI, 20.00, "i-026-048",
     "Vitaminas y minerales de calcio y fósforo para perros. Recomendado en gestación, lactancia y crecimiento. " + ruiland),
    ("Ruiland Cofactor 60 tabletas", RUI, 20.00, "i-026-049",
     "Aporta vitaminas y minerales; útil en deficiencias y excelente complemento para perros de alto rendimiento. " + ruiland),
    ("Ruiland Geriapet 60 tabletas", RUI, 36.00, "i-027-052",
     "Para un envejecimiento saludable: perros mayores más atentos y con mejor digestión. " + ruiland),
    ("Ruiland Omega 60 tabletas", RUI, 26.00, "i-027-050",
     "Provitaminas, vitaminas, minerales, aminoácidos y ácidos grasos esenciales que mejoran la piel y el pelaje de los perros; "
     "ayuda en tratamientos de artritis. " + ruiland),
    ("Ruiland Omega Gatos 60 tabletas", RUI, 29.00, "i-027-051",
     "Mejora la piel y el pelo de los gatos; recomendado en dermatitis, osteoartritis, inflamación, hiperlipidemia y "
     "enfermedades cardiacas. " + ruiland),

    ("Cefapet suspensión (cefalexina)", LIF, 8.10, "i-028-053",
     "Antibiótico para perros y gatos: infecciones de piel, vías urinarias, respiratorias, hueso y tejidos blandos. "
     "Cada 5 ml contienen 250 mg de cefalexina. Usar bajo indicación veterinaria. " + life),
    ("Moxipet suspensión (amoxicilina)", LIF, 6.50, "i-028-054",
     "Antibiótico para perros y gatos: infecciones respiratorias, gastrointestinales, urinarias, abscesos y piel. "
     "Cada 5 ml contienen 250 mg de amoxicilina. Usar bajo indicación veterinaria. " + life),
    ("Sultri-Pet jarabe", LIF, 4.90, "i-029-056",
     "Trimetoprim 40 mg + sulfametoxazol 200 mg cada 5 ml. Infecciones entéricas, respiratorias, urinarias y cutáneas en "
     "perros y gatos. Usar bajo indicación veterinaria. " + life),
    ("Bongo Vita-B", LIF, 4.20, "i-029-055",
     "Complejo B para perros: previene y trata inapetencia, decaimiento, crecimiento reducido y pérdida de peso. " + life),
    ("Bongo Forte suspensión 2 ml", LIF, 2.40, "i-030-058", bongo),
    ("Bongo Forte suspensión 5 ml", LIF, 3.00, "i-030-058", bongo),
    ("Bongo Forte suspensión 10 ml", LIF, 3.80, "i-030-058", bongo),

    ("Collar Dominal perro pequeño", DOM, 6.90, "i-031-059", dominal),
    ("Collar Dominal perro mediano", DOM, 8.20, "i-031-059", dominal),
    ("Collar Dominal perro grande", DOM, 9.20, "i-031-059", dominal),
    ("Collar Dominal perro gigante", DOM, 9.90, "i-031-059", dominal),
    ("Collar Dominal gato", DOM, 6.90, "i-031-059", dominal),

    ("Dispensador de medicamentos", VAR, 7.00, "i-032-061",
     "Dispensador de pastillas, cápsulas o líquidos para perros, gatos y mamíferos pequeños. Punta de silicona suave, lavable, "
     "reutilizable y de materiales no tóxicos: asegura que la mascota reciba la dosis completa."),
    ("Tubo endotraqueal para gato", VAR, 13.00, "i-033-062",
     "Tubo de gel suave de grado médico con diseño anti-mordidas y sellado hermético. Tallas: C1 (1–2 kg), C2 (1,5–3,5 kg), "
     "C3 (3–5 kg); indica la talla al hacer el pedido."),
    ("Catéter urinario para gato (Kruuse)", VAR, 9.00, "i-034-064",
     "Catéter estéril de polietileno libre de DEHP con estilete, 2 orificios laterales y conector Luer Lock. Medidas: "
     "1.0x130 mm (gatos pequeños) o 1.3x130 mm (medianos a grandes); indica la medida al hacer el pedido. Uso de 1 a 3 días."),
]


def sql(s: str) -> str:
    return "'" + s.replace("'", "''") + "'"


def main() -> None:
    origen, destino = Path(sys.argv[1]), Path(sys.argv[2])
    destino.mkdir(parents=True, exist_ok=True)
    assert len({p[0] for p in P}) == len(P), "nombres repetidos"
    for _, _, precio, img, _ in P:
        assert precio > 0 and (origen / f"{img}.png").exists(), img
    for img in sorted({p[3] for p in P}):
        # jpg de 800 px sobre fondo blanco (algunas png traen transparencia)
        subprocess.run(["convert", str(origen / f"{img}.png"), "-background", "white", "-flatten",
                        "-resize", "800x800>", "-quality", "85", str(destino / f"{img}.jpg")], check=True)
    filas = [f"  ({sql(n)}, {sql(c)}, {p:.2f}, 10, {sql(URL + i + '.jpg')}, {sql(d)})" for n, c, p, i, d in P]
    Path(__file__).with_name("productos.sql").write_text(
        "-- Generado por generar.py desde CATÁLOGO 2026-09-23.pdf\n"
        "insert into public.productos (nombre, categoria, precio, stock, imagen_url, descripcion) values\n"
        + ",\n".join(filas) + ";\n")
    print(len(P), "productos,", len({p[3] for p in P}), "fotos")


main()
