#!/bin/bash
set -e

# Create the n8n database if it doesn't exist
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Create extensions that n8n might need
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    CREATE EXTENSION IF NOT EXISTS "pgcrypto";
    
    -- Grant necessary permissions to the n8n user
    GRANT ALL PRIVILEGES ON DATABASE n8n TO n8n;
    GRANT ALL PRIVILEGES ON SCHEMA public TO n8n;
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO n8n;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO n8n;
    GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO n8n;
    
    -- Set default privileges for future objects
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO n8n;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO n8n;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO n8n;
EOSQL

echo "PostgreSQL database initialization completed successfully!"