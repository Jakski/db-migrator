-- Table for keeping track of releases
CREATE TABLE IF NOT EXISTS schema_version (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  version INTEGER,
  date TIMESTAMP
);

-- Initialize with version 0, if table is empty
INSERT INTO schema_version (version, date)
  SELECT 0, datetime('now','localtime')
  WHERE NOT EXISTS (
    SELECT * FROM schema_version
  );

-- Return latest version
SELECT version FROM schema_version ORDER BY id DESC LIMIT 1;
