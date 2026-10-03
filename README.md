# El Cuestionario Definitivo de FNAF

Cuestionario de 376 preguntas de alternativas con ranking global. Todo corre gratis en **GitHub Pages** (la página) y **Supabase** (el ranking).

## Archivos

| Archivo | Para qué sirve |
| --- | --- |
| `index.html` | La página completa |
| `preguntas.json` | El banco de preguntas en español (aquí agregas o corriges) |
| `preguntas.en.json` | La traducción al inglés |
| `config.js` | Los datos de conexión a tu Supabase |
| `supabase/1_esquema.sql` | Crea tablas, reglas de seguridad y funciones del ranking |
| `supabase/2_respuestas.sql` | La clave de respuestas que usa el servidor para corregir |
| `generar_respuestas.py` | Regenera `2_respuestas.sql` y revisa que las traducciones coincidan |

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

- **Nicks limpios:** los nicks con palabras ofensivas se rechazan (ver "Filtro de nicks").
- **Nick protegido:** el primer jugador que publica con un nick lo registra con su PIN (mínimo 6 caracteres). El PIN se guarda cifrado con bcrypt. Mayúsculas y minúsculas cuentan como el mismo nick.
- **Solo el dueño cambia su puntaje:** para publicar con un nick existente hay que dar su PIN. Tras 5 intentos fallidos, ese nick se bloquea 15 minutos.
- **Puntajes corregidos en el servidor:** la página envía las respuestas elegidas, no el puntaje. El servidor corrige con su propia clave, así que nadie puede inventar un "500/376".
- **Nadie toca las tablas directamente:** están cerradas con reglas de seguridad; solo se puede leer el ranking y llamar a las dos funciones públicas.
- **Se guarda el mejor turno:** si alguien juega de nuevo y saca menos, su puntaje del ranking no baja.

**Límites honestos:** como las respuestas correctas viajan dentro de la página (para mostrar al instante si acertaste), alguien con conocimientos técnicos podría leerlas y jugar "perfecto". Eso no permite modificar puntajes ajenos. Además, un PIN olvidado no se puede recuperar.

## Actualizar desde la versión anterior

1. En Supabase, vuelve a ejecutar `supabase/1_esquema.sql` completo. No borra jugadores ni puntajes: solo agrega el filtro de nicks y actualiza las funciones.
2. Después sube a GitHub `index.html` y `preguntas.en.json`. Hazlo en ese orden: la página nueva usa una función que crea el SQL.

## Idiomas

- La página detecta el idioma del navegador (español si es español; si no, inglés) y se puede cambiar en cualquier momento con los botones ES / EN, incluso en mitad del turno.
- Todos comparten un solo ranking: las traducciones usan los mismos `id` y el mismo orden de alternativas, así que el servidor corrige igual.
- **Si corriges una pregunta en un idioma, corrígela también en el otro.** Si cambias la alternativa correcta, debe ser la misma letra en ambos archivos. `generar_respuestas.py` te avisa si no coinciden.
- **Agregar otro idioma** (ej. portugués): crea `preguntas.pt.json` con los mismos `id` y la misma `correcta`, y en `index.html` agrega `pt` en `LANGS` y un bloque `pt` en `TEXT` con las frases de la interfaz.

## Filtro de nicks

- Las palabras prohibidas están en la tabla `banned_words` de Supabase. Puedes agregar o quitar filas desde el **Table Editor**, sin tocar código.
- Cada palabra tiene un modo:
  - `contains`: bloquea si aparece en cualquier parte del nick. Úsalo para palabras que no aparecen dentro de palabras normales.
  - `exact`: bloquea solo si es una palabra completa del nick (separada por `_`, `.` o `-`, o el nick entero). Úsalo para palabras cortas, para no bloquear por ejemplo "computador" por contener "puta".
- El filtro ignora mayúsculas, tildes, números usados como letras (4 = a, 3 = e, 0 = o…) y letras repetidas, así que "FuUuck" o "PUT4" también se bloquean.
- **Nicks que ya existían:** si alguno contiene una palabra prohibida, desaparece del ranking automáticamente y ya no puede publicar. Sus datos no se borran. Si quieres eliminarlo del todo, bórralo desde la tabla `players` (su puntaje se borra con él).
- Ningún filtro automático es perfecto: puede bloquear algún nick inocente (por ejemplo, "Shitake" contiene "shit") o dejar pasar insultos creativos. Si pasa, ajusta la lista.

## Ranking

Se ordena por **respuestas correctas**. En empate gana quien respondió **menos preguntas**, y si siguen empatados, quien llegó primero. El filtro "Turno completo" muestra solo a quienes jugaron todas las partes.

## Agregar o corregir preguntas

1. Edita `preguntas.json` y también `preguntas.en.json`. Cada pregunta tiene esta forma:

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
