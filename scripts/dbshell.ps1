# opens a mysql prompt inside the container
$dbPass = ((Get-Content .env | Where-Object { $_ -match '^MYSQL_ROOT_PASSWORD=' }) -replace '^MYSQL_ROOT_PASSWORD=','').Trim()
docker exec -it -e MYSQL_PWD=$dbPass samuhledger-db mysql -uroot samuhledger