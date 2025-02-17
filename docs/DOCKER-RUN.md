# Using PgOSM-Flex within Docker

This README provides details about running PgOSM-Flex using the image defined
in `Dockerfile` and the script loaded from `docker/pgosm_flex.py`.


## Setup and Run Container

Create directory for the `.osm.pbf` file and output `.sql` file.

```bash
mkdir ~/pgosm-data
```


Set environment variables for the temporary Postgres connection in Docker.

```bash
export POSTGRES_USER=postgres
export POSTGRES_PASSWORD=mysecretpassword
```


Start the `pgosm` Docker container to make PostgreSQL/PostGIS available.
This command exposes Postgres inside Docker on port 5433 and establishes links
to the local directory created above (`~/pgosm-data`).
Using `-v /etc/localtime:/etc/localtime:ro` allows the Docker image to use
your the host machine's timezone, important when for archiving PBF & MD5 files by date.


```bash
docker run --name pgosm -d --rm \
    -v ~/pgosm-data:/app/output \
    -v /etc/localtime:/etc/localtime:ro \
    -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
    -p 5433:5432 -d rustprooflabs/pgosm-flex
```

Ensure the docker container is running.

```bash
docker ps -a | grep pgosm
```

> The most common reason the Docker container fails to run is not setting the `$POSTGRES_PASSWORD` env var.


## Run PgOSM-Flex

The following `docker exec` command runs PgOSM Flex to load the District of Columbia
region

The command  `python3 docker/pgosm_flex.py` runs the full process. The
script uses a region (`north-america/us`) and sub-region (`district-of-columbia`)
that must match values in URLs from the Geofabrik download server.
The 3rd parameter tells the script the server has 8 GB RAM available for osm2pgsql, Postgres, and the OS.  The PgOSM-Flex layer set is defined (`default`).


```bash
docker exec -it \
    pgosm python3 docker/pgosm_flex.py \
    --layerset=default \
    --ram=8 \
    --region=north-america/us \
    --subregion=district-of-columbia \
    &> ~/pgosm-data/pgosm-flex.log
```


## Customize PgOSM-Flex

See full set of options via `--help`.

```bash
docker exec -it pgosm python3 docker/pgosm_flex.py --help
```

```bash
Usage: pgosm_flex.py [OPTIONS]

  Logic to run PgOSM Flex within Docker.

Options:
  --layerset TEXT       Layer set from PgOSM Flex to load.  [default:
                        (default); required]
  --layerset-path TEXT  Custom path to load layerset INI from. Custom paths
                        should be mounted to Docker via docker run -v ...
  --ram INTEGER         Amount of RAM in GB available on the server running
                        this process. Used to determine appropriate osm2pgsql
                        command via osm2pgsql-tuner.com API.  [default: 4;
                        required]
  --region TEXT         Region name matching the filename for data sourced
                        from Geofabrik. e.g. north-america/us  [default:
                        (north-america/us); required]
  --subregion TEXT      Sub-region name matching the filename for data sourced
                        from Geofabrik. e.g. district-of-columbia  [default:
                        (district-of-columbia)]
  --srid TEXT           SRID for data in PostGIS.  Defaults to 3857
  --pgosm-date TEXT     Date of the data in YYYY-MM-DD format. If today
                        (default), automatically downloads when files not
                        found locally. Set to historic date to load locally
                        archived PBF/MD5 file, will fail if both files do not
                        exist.
  --language TEXT       Set default language in loaded OpenStreetMap data when
                        available.  e.g. 'en' or 'kn'.
  --schema-name TEXT    Change the final schema name, defaults to 'osm'.
  --skip-nested         When set, skips calculating nested admin polygons. Can
                        be time consuming on large regions.
  --data-only           When set, skips running Sqitch and importing QGIS
                        Styles.
  --skip-dump           Skips the final pg_dump at the end. Useful for local
                        testing when not loading into more permanent instance.
  --debug               Enables additional log output
  --basepath TEXT       Debugging option. Used when testing locally and not
                        within Docker
  --help                Show this message and exit.
```

An example of running with all current options, except `--basepath` which is only
used during development.

```bash
docker exec -it \
    pgosm python3 docker/pgosm_flex.py \
    --layerset=poi \
    --layerset-path=/custom-layerset/ \
    --ram=8 \
    --region=north-america/us \
    --subregion=district-of-columbia \
    --schema-name=osm_dc \
    --pgosm-date="2021-03-11" \
    --language="en" \
    --srid="4326" \
    --data-only \
    --skip-dump \
    --skip-nested \
    --debug
```

## Use custom layersets

See [LAYERSETS.md](LAYERSETS.md).

To use the `--layerset-path` option for custom layerset
definitions, link the directory containing custom styles
to the Docker container in the `docker run` command.
The custom styles will be available inside the container under
`/custom-layerset`.


```bash
docker run --name pgosm -d --rm \
    -v ~/pgosm-data:/app/output \
    -v /etc/localtime:/etc/localtime:ro \
    -v ~/custom-layerset:/custom-layerset \
    -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
    -p 5433:5432 -d rustprooflabs/pgosm-flex
```

Define the layerset name (`--layerset=poi`) and path
(`--layerset-path`) to the `docker exec`.


```bash
docker exec -it \
    pgosm python3 docker/pgosm_flex.py \
    --layerset=poi \
    --layerset-path=/custom-layerset/ \
    --ram=8 \
    --region=north-america/us \
    --subregion=district-of-columbia
```


## Skip nested polygon calculation

Use `--skip-nested` to bypass the calculation of nested admin polygons.

The default is to run the nested polygon calculation. This can take considerable time on larger regions or may
be otherwise unwanted.


## Configure Postgres in Docker

Add customizations with the `-c` switch, e.g. `-c shared_buffers=1GB`,
to customize Postgres' configuration at run-time in Docker.


```bash
docker run --name pgosm -d --rm \
    -v ~/pgosm-data:/app/output \
    -v /etc/localtime:/etc/localtime:ro \
    -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
    -p 5433:5432 -d rustprooflabs/pgosm-flex \
    -c shared_buffers=1GB \
    -c maintenance_work_mem=1GB \
    -c checkpoint_timeout=300min \
    -c max_wal_senders=0 -c wal_level=minimal \
    -c checkpoint_completion_target=0.9 \
    -c random_page_cost=1.0
```



