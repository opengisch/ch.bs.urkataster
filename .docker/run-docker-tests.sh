#!/usr/bin/env bash
set -e

export PGHOST=${PGHOST-postgres}

# rationale: Wait for postgres container to become available
echo "Wait a moment while loading the database."
while ! PGPASSWORD='docker' psql -h $PGHOST -U docker -p 5432 -l &> /dev/null
do
  printf "."
  sleep 2
done
echo "up"

pushd /usr/src

# restore dump for testdata
echo "Restore test db from dump"
echo "... add extension uuid-ossp (postgis already in docker)"
PGPASSWORD='docker' psql -h $PGHOST -U docker -d urk -c 'CREATE EXTENSION "uuid-ossp";'
echo "... create schema and tables urkataster"
PGPASSWORD='docker' psql -h $PGHOST -U docker -d urk -f database/create_schema.sql > /dev/null
echo "... import test data"
PGPASSWORD='docker' psql -h $PGHOST -U docker -d urk -f tests/testdata/dumps/test-dataset.sql > /dev/null
echo ""

DEFAULT_PARAMS='-v'
xvfb-run python -m pytest ${@:-`echo $DEFAULT_PARAMS`} $1 $2
popd
