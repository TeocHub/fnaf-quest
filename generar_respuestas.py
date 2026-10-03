"""Genera supabase/2_respuestas.sql a partir de preguntas.json y revisa
que cada traducción (preguntas.XX.json) coincida con el original.

Úsalo cada vez que agregues, quites o corrijas preguntas:
    python generar_respuestas.py
y luego ejecuta supabase/2_respuestas.sql en el SQL Editor de Supabase.
"""
import json, pathlib, re, sys

base = pathlib.Path(__file__).parent

def leer(nombre):
    return json.loads((base / nombre).read_text(encoding="utf-8"))

partes = leer("preguntas.json")

filas, ref = [], {}
for parte in partes:
    n = int(parte["parte"])
    for q in parte["preguntas"]:
        qid = q["id"]
        if not re.fullmatch(r"[A-Za-z0-9_-]+", qid):
            sys.exit(f"ID inválido: {qid}")
        if qid in ref:
            sys.exit(f"ID repetido: {qid}")
        if len(q["opciones"]) != 4 or q["correcta"] not in "abcd":
            sys.exit(f"Pregunta mal formada: {qid}")
        ref[qid] = (n, q["correcta"])
        filas.append(f"  ('{qid}', {n}, {'abcd'.index(q['correcta'])})")

# Revisar traducciones
for archivo in sorted(base.glob("preguntas.*.json")):
    trad = {}
    for parte in leer(archivo.name):
        for q in parte["preguntas"]:
            if len(q["opciones"]) != 4:
                sys.exit(f"{archivo.name}: {q['id']} no tiene 4 opciones")
            trad[q["id"]] = (int(parte["parte"]), q["correcta"])
    faltan = set(ref) - set(trad)
    sobran = set(trad) - set(ref)
    distintas = [i for i in ref if i in trad and trad[i] != ref[i]]
    if faltan or sobran or distintas:
        sys.exit(f"{archivo.name} no coincide con preguntas.json.\n"
                 f"  Faltan: {sorted(faltan)[:10]}\n  Sobran: {sorted(sobran)[:10]}\n"
                 f"  Distinta parte o respuesta correcta: {distintas[:10]}")
    print(f"{archivo.name}: OK")

sql = (
    "-- Generado por generar_respuestas.py. No lo edites a mano.\n"
    "begin;\n"
    "delete from public.answer_key;\n"
    "insert into public.answer_key (qid, part, correct) values\n"
    + ",\n".join(filas) + ";\n"
    "commit;\n"
)
(base / "supabase" / "2_respuestas.sql").write_text(sql, encoding="utf-8")
print(f"Listo: {len(filas)} respuestas en supabase/2_respuestas.sql")
