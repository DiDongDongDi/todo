-- Merge legacy note into title, then drop note column from tasks and templates.

UPDATE tasks
SET title = trim(both from title || E'\n' || note)
WHERE note IS NOT NULL AND trim(note) <> '';

ALTER TABLE tasks DROP COLUMN IF EXISTS note;

UPDATE task_templates
SET title = trim(both from title || E'\n' || note)
WHERE note IS NOT NULL AND trim(note) <> '';

ALTER TABLE task_templates DROP COLUMN IF EXISTS note;
