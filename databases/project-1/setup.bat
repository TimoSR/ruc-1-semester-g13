@echo off
setlocal enabledelayedexpansion

REM Load .env file
for /f "tokens=1,* delims==" %%A in ('findstr /v "^#\|^$" .env') do (
    set "%%A=%%B"
)

if not defined DB_NAME (
    echo ❌ Failed to load .env file or DB_NAME is missing.
    exit /b 1
)

echo 🧨 Terminating active connections on %DB_NAME%...
psql "%DB_URL_ADMIN%" -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '%DB_NAME%' AND pid <> pg_backend_pid();"

echo 💣 Dropping database %DB_NAME%...
psql "%DB_URL_ADMIN%" -c "DROP DATABASE IF EXISTS \"%DB_NAME%\";"

echo 🛠️  Creating database %DB_NAME%...
psql "%DB_URL_ADMIN%" -c "CREATE DATABASE \"%DB_NAME%\";"

echo 📦 Running init.sql (includes schema and seed)...
psql "%DB_URL_TARGET%" -f init.sql

echo ✅ Database setup complete.
endlocal