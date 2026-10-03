# El Cuestionario Definitivo de FNAF

Cuestionario de 376 preguntas de alternativas con ranking global. Todo corre gratis en **GitHub Pages** (la página) y **Supabase** (el ranking).

## Archivos

| Archivo | Para qué sirve |
| --- | --- |
| `index.html` | La página completa |
| `preguntas.json` | El banco de preguntas (aquí agregas o corriges) |
| `config.js` | Los datos de conexión a tu Supabase |
| `supabase/1_esquema.sql` | Crea tablas, reglas de seguridad y funciones del ranking |
| `supabase/2_respuestas.sql` | La clave de respuestas que usa el servidor para corregir |
| `generar_respuestas.py` | Regenera `2_respuestas.sql` cuando cambias preguntas |

## 1. Crear el servidor del ranking (Supabase, gratis)

1. Crea una cuenta en [supabase.com](https://supabase.com) y un proyecto nuevo. Elige la región más cercana (por ejemplo, São Paulo) y guarda la contraseña de la base de datos.
2. Abre el **SQL Editor**, pega el contenido de `supabase/1_esquema.sql` y presiona **Run**.
3. Haz lo mismo con `supabase/2_respuestas.sql`.

Supabase puede mostrar un aviso sobre la vista `leaderboard` ("security definer"). Es intencional: la vista solo expone nick y puntajes, nunca los PIN.

## 2. Conectar la página

En la configuración del proyecto, busca la sección de **API** y copia:

- la **Project URL** (algo como `https://abcd1234.supabase.co`),
- la clave pública (**anon public** o **publishable**). Nunca uses la `service_role` ni la `secret`.

Pégalas en `config.js`.

## 3. Publicar la página (GitHub Pages, gratis)

1. Crea un repositorio **público** y sube todos los archivos (la carpeta `supabase` y el `.py` pueden ir también; no afectan).
2. Ve a **Settings → Pages**, elige publicar desde la rama `main`, carpeta `/ (root)`.
3. En unos minutos queda en `https://tu-usuario.github.io/nombre-del-repo/`.

Ojo: si abres `index.html` con doble clic desde tu computador, no carga las preguntas. Pruébalo ya publicado o con un servidor local (`python -m http.server` en la carpeta).

## Cómo funciona la seguridad

- **Nick protegido:** el primer jugador que publica con un nick lo registra con su PIN (mínimo 6 caracteres). El PIN se guarda cifrado con bcrypt. Mayúsculas y minúsculas cuentan como el mismo nick.
- **Solo el dueño cambia su puntaje:** para publicar con un nick existente hay que dar su PIN. Tras 5 intentos fallidos, ese nick se bloquea 15 minutos.
- **Puntajes corregidos en el servidor:** la página envía las respuestas elegidas, no el puntaje. El servidor corrige con su propia clave, así que nadie puede inventar un "500/376".
- **Nadie toca las tablas directamente:** están cerradas con reglas de seguridad; solo se puede leer el ranking y llamar a las dos funciones públicas.
- **Se guarda el mejor turno:** si alguien juega de nuevo y saca menos, su puntaje del ranking no baja.

**Límites honestos:** como las respuestas correctas viajan dentro de la página (para mostrar al instante si acertaste), alguien con conocimientos técnicos podría leerlas y jugar "perfecto". Eso no permite modificar puntajes ajenos. Además, un PIN olvidado no se puede recuperar.

## Ranking

Se ordena por **respuestas correctas**. En empate gana quien respondió **menos preguntas**, y si siguen empatados, quien llegó primero. El filtro "Turno completo" muestra solo a quienes jugaron todas las partes.

## Agregar o corregir preguntas

1. Edita `preguntas.json`. Cada pregunta tiene esta forma:

```json
{
  "id": "p7-103",
  "nivel": "A",
  "sub": "Otros libros",
  "pregunta": "¿Pregunta?",
  "opciones": ["opción a", "opción b", "opción c", "opción d"],
  "correcta": "c"
}
```

   - `id` debe ser único y no cambiar nunca (el ranking lo usa).
   - `nivel`: `B`, `I`, `A` o `E`.
   - Para una parte nueva, agrega otro bloque con `parte`, `corto`, `titulo` y `preguntas`.

2. Ejecuta `python generar_respuestas.py`.
3. Ejecuta el nuevo `supabase/2_respuestas.sql` en el SQL Editor.
4. Sube los cambios a GitHub.

## Plan gratuito: qué esperar

- GitHub Pages: gratis para repositorios públicos.
- Supabase: el plan gratuito incluye 500 MB de base de datos, de sobra para muchos miles de jugadores. Un proyecto gratuito **se pausa tras una semana sin actividad**; se reactiva desde el panel con un clic.

## Si algo falla

- **"No se pudo cargar preguntas.json":** estás abriendo el archivo localmente o falta subirlo.
- **No aparece el botón de ranking:** `config.js` está vacío o mal escrito.
- **"No hay conexión con el servidor del ranking":** revisa la URL y la clave en `config.js`, y que el proyecto de Supabase no esté pausado.
