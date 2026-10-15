-- ============================================================
-- MediCore EMR — System Backups Schema (Supabase PostgreSQL)
-- ============================================================

CREATE TABLE IF NOT EXISTS system_backups (
  id BIGSERIAL PRIMARY KEY,
  backup_name VARCHAR(255) NOT NULL,
  destination VARCHAR(50) NOT NULL DEFAULT 'supabase_cloud',
  backup_type VARCHAR(50) NOT NULL DEFAULT 'Manual',
  status VARCHAR(50) NOT NULL DEFAULT 'Completado',
  size_bytes BIGINT NOT NULL DEFAULT 0,
  size_formatted VARCHAR(50) NOT NULL DEFAULT '0 KB',
  tables_count INT NOT NULL DEFAULT 0,
  records_count INT NOT NULL DEFAULT 0,
  duration_seconds NUMERIC(8,2) NOT NULL DEFAULT 0,
  file_path TEXT NULL,
  backup_data JSONB NOT NULL,
  performed_by VARCHAR(255) NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for fast ordering and querying
CREATE INDEX IF NOT EXISTS idx_system_backups_created_at ON system_backups(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_system_backups_destination ON system_backups(destination);

-- Enable RLS and public access policies
ALTER TABLE system_backups ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow anon read system_backups"
  ON system_backups FOR SELECT
  USING (true);

CREATE POLICY "Allow anon insert system_backups"
  ON system_backups FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Allow anon update system_backups"
  ON system_backups FOR UPDATE
  USING (true);

CREATE POLICY "Allow anon delete system_backups"
  ON system_backups FOR DELETE
  USING (true);
