-- Merge legacy note into title, then drop note column (idempotent).

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'tasks'
      AND column_name = 'note'
  ) THEN
    UPDATE public.tasks
    SET title = trim(both from title || E'\n' || note)
    WHERE note IS NOT NULL AND trim(note) <> '';

    ALTER TABLE public.tasks DROP COLUMN note;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'task_templates'
      AND column_name = 'note'
  ) THEN
    UPDATE public.task_templates
    SET title = trim(both from title || E'\n' || note)
    WHERE note IS NOT NULL AND trim(note) <> '';

    ALTER TABLE public.task_templates DROP COLUMN note;
  END IF;
END $$;
