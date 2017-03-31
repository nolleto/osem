#! /bin/bash

set -e

# data directory is required for caching the secret key in a file
if [ "$DATA_DIR" == "" ]; then
    echo -n "Error: DATA_DIR environment variable not set!"
    echo "Are you sure you are running this script in a Docker container?"
    exit 1
fi

SECRET_KEY_FILE="$DATA_DIR/secret_key"

if [ ! -f "$SECRET_KEY_FILE" ]; then
    install -m 0600 /dev/null "$SECRET_KEY_FILE"
    SECRET_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 100 | head -n 1)
    echo "$key" > "$SECRET_KEY_FILE"
    chmod -w "$SECRET_KEY_FILE"
else
    SECRET_KEY=$(cat "$SECRET_KEY_FILE")
fi

export SECRET_KEY
export RAILS_ENV=production

install -m 0600 /dev/null .my.cnf
cat > .my.cnf <<ABC
[client]
user=$MYSQL_USER
password=$MYSQL_PASSWORD
ABC

if [ $(echo "show tables;" | mysql --host $DATABASE_HOST --port $DATABASE_PORT $MYSQL_DATABASE | wc -l) -le 1 ]; then
    echo ">>> Initializing database..."
    dockerize -wait tcp://$DATABASE_HOST:$DATABASE_PORT -timeout 60s bundle exec rake db:schema:load
fi

echo ">>> Upgrading database..."
dockerize -wait tcp://$DATABASE_HOST:$DATABASE_PORT -timeout 60s bundle exec rake db:migrate

rm .my.cnf

echo ">>> Precompiling assets..."
bundle exec rake assets:precompile

echo ">>> Starting application server..."
exec bundle exec rails server -e production -p 9292
