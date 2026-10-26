# usage: .\scripts\runsql.ps1 database\01_schema.sql
param([Parameter(Mandatory=$true)][string]$File)
$dbPass = ((Get-Content .env | Where-Object { $_ -match '^MYSQL_ROOT_PASSWORD=' }) -replace '^MYSQL_ROOT_PASSWORD=','').Trim()
Get-Content $File -Raw | docker exec -i -e MYSQL_PWD=$dbPass samuhledger-db mysql -uroot samuhledger