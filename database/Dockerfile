FROM mysql:8.4

COPY mysql/schema.sql /docker-entrypoint-initdb.d/01-schema.sql
COPY mysql/seed.sql /docker-entrypoint-initdb.d/02-seed.sql
