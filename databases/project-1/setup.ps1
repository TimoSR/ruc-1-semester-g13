# Requires PowerShell 5.0+
# Set the working directory to the location of the script
# Safe alternative
Set-Location -Path $PSScriptRoot

Write-Host "📂 Loading .env file..."

# Load .env file (ignore lines starting with # or empty)
Get-Content ".env" | ForEach-Object {
    if ($_ -match '^\s*#' -or $_ -match '^\s*$') { return }

    if ($_ -match '^\s*([^=]+?)\s*=\s*(.*)\s*$') {
        $key = $matches[1].Trim()
        $value = $matches[2].Trim('"')  # remove surrounding quotes if present
        [System.Environment]::SetEnvironmentVariable($key, $value, "Process")
    }
}

# Retrieve required environment variables
$DB_NAME       = $env:DB_NAME
$DB_URL_ADMIN  = $env:DB_URL_ADMIN
$DB_URL_TARGET = $env:DB_URL_TARGET

if (-not $DB_NAME) {
    Write-Host "❌ Failed to load .env file or DB_NAME is missing." -ForegroundColor Red
    exit 1
}

Write-Host "🧨 Terminating active connections on $DB_NAME..."
& psql "$DB_URL_ADMIN" -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid();"

Write-Host "💣 Dropping database $DB_NAME..."
& psql "$DB_URL_ADMIN" -c "DROP DATABASE IF EXISTS `"$DB_NAME`";"

Write-Host "🛠️  Creating database $DB_NAME..."
& psql "$DB_URL_ADMIN" -c "CREATE DATABASE `"$DB_NAME`";"

Write-Host "📦 Running init.sql (includes schema and seed)..."
& psql "$DB_URL_TARGET" -f "init.sql"

Write-Host "✅ Database setup complete." -ForegroundColor Green
