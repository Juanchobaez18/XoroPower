CREATE OR REPLACE FUNCTION public.delete_module_with_content(p_module_id text)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  has_modulo_id boolean;
  has_module_id boolean;
  module_filter text;
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (
    SELECT 1
    FROM public.users
    WHERE id::text = auth.uid()::text
      AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Solo un administrador puede eliminar módulos.';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.modules
    WHERE id::text = p_module_id
  ) THEN
    RAISE EXCEPTION 'El módulo no existe.';
  END IF;

  SELECT
    EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'exercises'
        AND column_name = 'modulo_id'
    ),
    EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'exercises'
        AND column_name = 'module_id'
    )
  INTO has_modulo_id, has_module_id;

  IF NOT has_modulo_id AND NOT has_module_id THEN
    RAISE EXCEPTION 'No se encontró la relación entre ejercicios y módulos.';
  END IF;

  module_filter := concat_ws(
    ' OR ',
    CASE WHEN has_modulo_id THEN 'e.modulo_id::text = $1' END,
    CASE WHEN has_module_id THEN 'e.module_id::text = $1' END
  );

  EXECUTE format(
    'DELETE FROM public.progreso_usuario AS p
     USING public.exercises AS e
     WHERE p.id_ejercicio::text = e.id::text
       AND (%s)',
    module_filter
  )
  USING p_module_id;

  EXECUTE format(
    'DELETE FROM public.exercises AS e WHERE %s',
    module_filter
  )
  USING p_module_id;

  DELETE FROM public.modules AS m
  WHERE m.id::text = p_module_id;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_module_with_content(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_module_with_content(text) TO authenticated;
