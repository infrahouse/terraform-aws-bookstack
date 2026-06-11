#!/usr/bin/env bash
set -e

# Database connectivity test script for BookStack
# Reads database configuration from puppet facter and tests MySQL connection

FACTER_FILE="/etc/puppetlabs/facter/facts.d/custom.json"

echo "Reading database configuration from facter..."

# Check if facter file exists
if [ ! -f "$FACTER_FILE" ]; then
    echo "ERROR: Facter file not found at $FACTER_FILE"
    exit 1
fi

# Read database configuration from facter
DB_HOST=$(jq -r '.bookstack.db_host' "$FACTER_FILE")
DB_PORT=$(jq -r '.bookstack.db_port' "$FACTER_FILE")
DB_DATABASE=$(jq -r '.bookstack.db_database' "$FACTER_FILE")
DB_USERNAME=$(jq -r '.bookstack.db_username' "$FACTER_FILE")
DB_PASSWORD_SECRET=$(jq -r '.bookstack.db_password_secret' "$FACTER_FILE")

echo "Database host: $DB_HOST"
echo "Database port: $DB_PORT"
echo "Database name: $DB_DATABASE"
echo "Database user: $DB_USERNAME"
echo "Password secret: $DB_PASSWORD_SECRET"

# Get database password from Secrets Manager
echo "Retrieving database password from Secrets Manager..."
DB_PASSWORD=$(ih-secrets get "$DB_PASSWORD_SECRET" | jq -r '.password')

if [ -z "$DB_PASSWORD" ] || [ "$DB_PASSWORD" == "null" ]; then
    echo "ERROR: Failed to retrieve database password"
    exit 1
fi

# Test database connectivity with SELECT 1.
# Pass the password via MYSQL_PWD so it is taken literally. A MySQL option file
# treats characters such as '#' (comment) and '\' (escape) specially, which
# corrupts AWS-managed RDS passwords that contain them.
echo "Testing database connection to $DB_HOST:$DB_PORT..."
if MYSQL_PWD="$DB_PASSWORD" mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USERNAME" "$DB_DATABASE" -e "SELECT 1 AS test_connection;" 2>&1; then
    echo "Database connectivity test PASSED"
    exit 0
else
    echo "Database connectivity test FAILED"
    exit 1
fi
