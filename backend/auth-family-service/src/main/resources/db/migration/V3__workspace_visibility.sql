ALTER TABLE family ADD COLUMN workspace_pending BOOLEAN NOT NULL DEFAULT FALSE;
CREATE UNIQUE INDEX uk_workspace_family ON family_workspace_request (family_id);
