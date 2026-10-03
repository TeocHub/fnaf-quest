-- =====================================================================
-- El Cuestionario Definitivo de FNAF: ranking global
-- Pega este archivo completo en el SQL Editor de Supabase y ejecútalo.
-- Después ejecuta 2_respuestas.sql.
-- =====================================================================

create extension if not exists pgcrypto with schema extensions;

-- ---------- Tablas ----------

-- Jugadores: cada nick pertenece a quien lo registró primero.
-- El PIN se guarda cifrado con bcrypt; nunca en texto plano.
create table if not exists public.players (
  id              bigint generated always as identity primary key,
  nick            text        not null,
  nick_key        text        generated always as (lower(nick)) stored unique,
  pin_hash        text        not null,
  failed_attempts int         not null default 0,
  locked_until    timestamptz,
  created_at      timestamptz not null default now()
);

-- Clave de respuestas: el servidor corrige con esta tabla,
-- así nadie puede inventar un puntaje imposible.
create table if not exists public.answer_key (
  qid     text     primary key,      -- ej. "p1-001"
  part    smallint not null,         -- número de parte
  correct smallint not null check (correct between 0 and 3)
);

-- Mejor puntaje de cada jugador.
create table if not exists public.scores (
  player_id  bigint      primary key references public.players(id) on delete cascade,
  correct    int         not null,
  answered   int         not null,
  total      int         not null,
  parts      smallint[]  not null,
  updated_at timestamptz not null default now()
);

-- ---------- Seguridad ----------
-- RLS activado y SIN políticas: nadie puede leer ni escribir estas
-- tablas directamente desde la web. Todo pasa por las funciones de abajo.
alter table public.players    enable row level security;
alter table public.answer_key enable row level security;
alter table public.scores     enable row level security;

revoke all on public.players, public.answer_key, public.scores from anon, authenticated;

-- ---------- Ranking público (solo lectura) ----------
-- Expone únicamente nick y números; nunca el PIN.
create or replace view public.leaderboard as
select
  p.nick,
  s.correct,
  s.answered,
  s.total,
  s.parts,
  round(100.0 * s.correct / nullif(s.answered, 0), 1) as accuracy,
  s.updated_at
from public.scores s
join public.players p on p.id = s.player_id;

revoke all on public.leaderboard from anon, authenticated;
grant select on public.leaderboard to anon, authenticated;

-- ---------- ¿Está ocupado este nick? ----------
create or replace function public.nick_taken(p_nick text)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (select 1 from public.players where nick_key = lower(btrim(p_nick)));
$$;

-- ---------- Publicar puntaje ----------
-- Recibe nick, PIN, partes jugadas y respuestas {"p1-001": 1, ...}.
-- Si el nick no existe, lo registra con ese PIN.
-- Si existe, exige el PIN correcto (5 fallos = bloqueo de 15 minutos).
-- Corrige en el servidor y guarda solo si mejora el puntaje anterior.
create or replace function public.submit_score(
  p_nick    text,
  p_pin     text,
  p_parts   int[],
  p_answers jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_player   public.players%rowtype;
  v_best     public.scores%rowtype;
  v_new      boolean := false;
  v_improved boolean := false;
  v_parts    smallint[];
  v_total    int;
  v_answered int;
  v_correct  int;
  v_fails    int;
  v_rank     int;
begin
  p_nick := btrim(coalesce(p_nick, ''));

  if p_nick !~ '^[A-Za-z0-9_.ÁÉÍÓÚÜÑáéíóúüñ-]{3,20}$' then
    return jsonb_build_object('ok', false, 'error', 'nick_invalido');
  end if;
  if p_pin is null or length(p_pin) < 6 or length(p_pin) > 64 then
    return jsonb_build_object('ok', false, 'error', 'pin_invalido');
  end if;
  if p_answers is null or jsonb_typeof(p_answers) <> 'object' then
    return jsonb_build_object('ok', false, 'error', 'respuestas_invalidas');
  end if;

  v_parts := array(
    select distinct x::smallint from unnest(coalesce(p_parts, '{}')) as x
    where x between 1 and 99 order by 1
  );
  select count(*) into v_total from public.answer_key where part = any(v_parts);
  if v_total = 0 then
    return jsonb_build_object('ok', false, 'error', 'partes_invalidas');
  end if;

  -- Buscar o crear jugador (bloqueando la fila para evitar carreras)
  select * into v_player from public.players where nick_key = lower(p_nick) for update;

  if not found then
    begin
      insert into public.players (nick, pin_hash)
      values (p_nick, crypt(p_pin, gen_salt('bf', 10)))
      returning * into v_player;
      v_new := true;
    exception when unique_violation then
      return jsonb_build_object('ok', false, 'error', 'reintentar');
    end;
  else
    if v_player.locked_until is not null and v_player.locked_until > now() then
      return jsonb_build_object('ok', false, 'error', 'bloqueado', 'hasta', v_player.locked_until);
    end if;

    if v_player.pin_hash <> crypt(p_pin, v_player.pin_hash) then
      v_fails := v_player.failed_attempts + 1;
      if v_fails >= 5 then
        update public.players
           set failed_attempts = 0, locked_until = now() + interval '15 minutes'
         where id = v_player.id;
        return jsonb_build_object('ok', false, 'error', 'bloqueado', 'hasta', now() + interval '15 minutes');
      else
        update public.players set failed_attempts = v_fails where id = v_player.id;
        return jsonb_build_object('ok', false, 'error', 'pin_incorrecto', 'intentos_restantes', 5 - v_fails);
      end if;
    end if;

    update public.players set failed_attempts = 0, locked_until = null where id = v_player.id;
  end if;

  -- Corrección en el servidor: solo cuentan preguntas reales de las partes elegidas
  select count(*),
         count(*) filter (where a.value::text = k.correct::text)
    into v_answered, v_correct
    from jsonb_each(p_answers) as a
    join public.answer_key k on k.qid = a.key and k.part = any(v_parts);

  -- Guardar solo si mejora: más correctas, o igual de correctas con menos respondidas
  select * into v_best from public.scores where player_id = v_player.id;
  if not found
     or v_correct > v_best.correct
     or (v_correct = v_best.correct and v_answered < v_best.answered) then
    insert into public.scores (player_id, correct, answered, total, parts, updated_at)
    values (v_player.id, v_correct, v_answered, v_total, v_parts, now())
    on conflict (player_id) do update
      set correct = excluded.correct,
          answered = excluded.answered,
          total = excluded.total,
          parts = excluded.parts,
          updated_at = excluded.updated_at;
    v_improved := true;
    select * into v_best from public.scores where player_id = v_player.id;
  end if;

  -- Puesto en el ranking general
  select count(*) + 1 into v_rank
    from public.scores s
   where s.correct > v_best.correct
      or (s.correct = v_best.correct and s.answered < v_best.answered)
      or (s.correct = v_best.correct and s.answered = v_best.answered and s.updated_at < v_best.updated_at);

  return jsonb_build_object(
    'ok', true,
    'nuevo', v_new,
    'mejoro', v_improved,
    'correct', v_correct,
    'answered', v_answered,
    'total', v_total,
    'best_correct', v_best.correct,
    'best_answered', v_best.answered,
    'puesto', v_rank
  );
end;
$$;

revoke all on function public.nick_taken(text) from public;
revoke all on function public.submit_score(text, text, int[], jsonb) from public;
grant execute on function public.nick_taken(text) to anon, authenticated;
grant execute on function public.submit_score(text, text, int[], jsonb) to anon, authenticated;
