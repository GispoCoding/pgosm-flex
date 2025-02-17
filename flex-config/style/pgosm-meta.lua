require "helpers"

local driver = require('luasql.postgres')
local env = driver.postgres()

local pgosm_conn_env = os.getenv("PGOSM_CONN")
local pgosm_conn = nil

if pgosm_conn_env then
    pgosm_conn = pgosm_conn_env
else
    error('ENV VAR PGOSM_CONN must be set.')
end


local tables = {}

sql_create_table = [=[
CREATE TABLE IF NOT EXISTS osm.pgosm_flex (
    id BIGINT NOT NULL GENERATED BY DEFAULT AS IDENTITY,
    imported TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    osm_date date NOT NULL,
    default_date bool NOT NULL,
    region text NOT NULL,
    pgosm_flex_version text NOT NULL,
    srid text NOT NULL,
    project_url text NOT NULL,
    osm2pgsql_version text NOT NULL,
    "language" text NOT NULL,
    CONSTRAINT pk_osm_pgosm_flex PRIMARY KEY (id)
);
]=]



function pgosm_get_commit_hash()
    local cmd = 'git rev-parse --short HEAD'
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()

    result = string.gsub(result, "\n", "")
    return result
end

function pgosm_get_latest_tag()
    local cmd = 'git describe --abbrev=0'
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()

    result = string.gsub(result, "\n", "")
    return result
end


local commit_hash = pgosm_get_commit_hash()
local git_tag = pgosm_get_latest_tag()
local osm2pgsql_version = osm2pgsql.version
print ('PgOSM-Flex version:', git_tag, commit_hash)
local pgosm_flex_version = git_tag .. '-' .. commit_hash
local project_url = 'https://github.com/rustprooflabs/pgosm-flex'


-- Establish connection to Postgres
con = assert (env:connect(pgosm_conn))

print('ensuring pgosm_flex table exists.')
con:execute(sql_create_table)

if default_date then
    default_date_str = 'true'
else
    default_date_str = 'false'
end

local sql_insert = [[ INSERT INTO osm.pgosm_flex (osm_date, default_date, region, pgosm_flex_version, srid, project_url, osm2pgsql_version, "language") ]] ..
 [[ VALUES (']] ..
 con:escape(pgosm_date) .. [[', ]] ..
 default_date_str .. [[ , ']] .. -- special handling for boolean
 con:escape(pgosm_region) .. [[', ']] ..
 con:escape(pgosm_flex_version) .. [[', ']] ..
 con:escape(srid) .. [[', ']] ..
 con:escape(project_url) .. [[', ']] ..
 con:escape(osm2pgsql_version) .. [[', ']] ..
 con:escape(pgosm_language) .. [[' );]]


-- simple query to verify connection
cur = con:execute( sql_insert )

