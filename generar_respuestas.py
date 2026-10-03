"""Genera supabase/2_respuestas.sql a partir de preguntas.json.

Úsalo cada vez que agregues, quites o corrijas preguntas:
    python generar_respuestas.py
y luego ejecuta supabase/2_respuestas.sql en el SQL Editor de Supabase.
"""
import json, pathlib, re, sys

base = pathlib.Path(__file__).parent
partes = json.loads((base / "preguntas.json").read_text(encoding="utf-8"))

filas, vistos = [], set()
for parte in partes:
    n = int(parte["parte"])
    for q in parte["preguntas"]:
        qid = q["id"]
        if not re.fullmatch(r"[A-Za-z0-9_-]+", qid):
            sys.exit(f"ID inválido: {qid}")
        if qid in vistos:
            sys.exit(f"ID repetido: {qid}")
        vistos.add(qid)
        if len(q["opciones"]) != 4 or q["correcta"] not in "abcd":
            sys.exit(f"Pregunta mal formada: {qid}")
        filas.append(f"  ('{qid}', {n}, {'abcd'.index(q['correcta'])})")

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
