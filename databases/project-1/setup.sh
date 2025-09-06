#!/bin/bash
set -e

# Load .env file
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo "❌ .env file not found!"
  exit 1
fi

echo "🧨 Terminating active connections (if any)..."
psql "$DB_URL_ADMIN" <<EOF
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid();
EOF

echo "💣 Dropping and recreating database '$DB_NAME'..."
psql "$DB_URL_ADMIN" -c "DROP DATABASE IF EXISTS \"$DB_NAME\";"
psql "$DB_URL_ADMIN" -c "CREATE DATABASE \"$DB_NAME\";"

echo "📦 Running schema and seed files..."
psql "$DB_URL_TARGET" -f init.sql

echo "✅ Setup complete."