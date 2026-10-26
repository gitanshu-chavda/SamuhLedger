# scripts\rebuild_db.ps1 - drops the database and rebuilds it from the numbered SQL files
$root = Join-Path $PSScriptRoot '..'
$envFile = Join-Path $root '.env'
$dbPass = ((Get-Content $envFile | Where-Object { $_ -match '^MYSQL_ROOT_PASSWORD=' }) -replace '^MYSQL_ROOT_PASSWORD=','').Trim()

docker exec -i -e MYSQL_PWD=$dbPass samuhledger-db mysql -uroot -e "DROP DATABASE IF EXISTS samuhledger; CREATE DATABASE samuhledger CHARACTER SET utf8mb4;"

$files = @(
  'database\01_schema.sql', 'database\02_indexes.sql', 'database\03_triggers.sql',
  'database\04_procedures.sql', 'database\05_views.sql', 'database\06_events.sql',
  'database\seed\reference_data.sql', 'database\07_roles_grants.sql'
)
foreach ($f in $files) {
  $path = Join-Path $root $f
  if (Test-Path $path) {
    Write-Host "Running $f"
    Get-Content $path -Raw | docker exec -i -e MYSQL_PWD=$dbPass samuhledger-db mysql -uroot samuhledger
    if ($LASTEXITCODE -ne 0) { Write-Host "FAILED: $f" -ForegroundColor Red; break }
  } else {
    Write-Host "Skipping $f (not created yet)"
  }
}
Write-Host "Done."
