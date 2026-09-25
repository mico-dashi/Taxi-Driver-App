#!/usr/bin/env bash
# Runs the migration + ride-flow test against a throwaway local PostgreSQL.
# Usage: PGHOST=/tmp PGPORT=5432 PGUSER=postgres ./supabase/tests/run_local.sh
set -euo pipefail
cd "$(dirname "$0")/.."
DB=taksi_test_$$
createdb "$DB"
trap 'dropdb --if-exists "$DB"' EXIT
psql -q -v ON_ERROR_STOP=1 -d "$DB" -f tests/supabase_shim.sql
psql -q -v ON_ERROR_STOP=1 -d "$DB" -f migrations/20260925000000_init.sql
psql -q -v ON_ERROR_STOP=1 -d "$DB" -f seed.sql
psql -q -v ON_ERROR_STOP=1 -d "$DB" -f tests/ride_flow_test.sql
