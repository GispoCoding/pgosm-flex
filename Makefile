## ----------------------------------------------------------------------
## This Makefile builds and tests the PgOSM Flex Docker image.
##
## For full build/test use:
##    make
##
## To cleanup after you are done:
##    make docker-clean
## ----------------------------------------------------------------------
CURRENT_UID := $(shell id -u)
CURRENT_GID := $(shell id -g)
TODAY := $(shell date +'%Y-%m-%d')

.PHONY: all
all: docker-clean build-run-docker unit-tests

.PHONY: docker-clean
docker-clean: ## Stops pgosm Docker container and removes local pgosm-data directory
	@docker stop pgosm > /dev/null 2>&1 && echo "pgosm container removed"|| echo "pgosm container not present, nothing to remove"
	rm -rvf pgosm-data|| echo "folder pgosm-data did not exist"


.PHONY: build-run-docker
build-run-docker: ## Builds and runs PgOSM Flex with D.C. test file
	docker build -t rustprooflabs/pgosm-flex .
	docker run --name pgosm \
		--rm \
		-v $(shell pwd)/pgosm-data:/app/output \
		-v /etc/localtime:/etc/localtime:ro \
		-e POSTGRES_PASSWORD=mysecretpassword \
		-p 5433:5432 \
		-d \
		rustprooflabs/pgosm-flex
	# copy the test data pretending it's latest to avoid downloading each time
	docker cp tests/data/district-of-columbia-2021-01-13.osm.pbf \
		pgosm:/app/output/district-of-columbia-$(TODAY).osm.pbf
	docker cp tests/data/district-of-columbia-2021-01-13.osm.pbf.md5 \
		pgosm:/app/output/district-of-columbia-$(TODAY).osm.pbf.md5

	# allow files created in later step to be created
	docker exec -it pgosm \
		chown $(CURRENT_UID):$(CURRENT_GID) /app/output/
	# Needed for unit-tests
	docker exec -it pgosm \
		chown $(CURRENT_UID):$(CURRENT_GID) /app/docker/

	docker exec -it \
		-e POSTGRES_PASSWORD=mysecretpassword \
		-e POSTGRES_USER=postgres \
		-u $(CURRENT_UID):$(CURRENT_GID) \
		pgosm python3 docker/pgosm_flex.py  \
		--layerset=default \
		--ram=1 \
		--region=north-america/us \
		--subregion=district-of-columbia \
		--debug


.PHONY: unit-tests
unit-tests: ## Runs Python unit tests and data import tests
	# Unit tests covering Python runtime
	docker exec -it \
		-e POSTGRES_PASSWORD=mysecretpassword \
		-e POSTGRES_USER=postgres \
		-u $(CURRENT_UID):$(CURRENT_GID) \
		pgosm /bin/bash -c "cd docker && coverage run -m unittest tests/*.py"

	# Data import tests
	docker cp tests \
		pgosm:/app/tests
	docker exec -it pgosm \
		chown $(CURRENT_UID):$(CURRENT_GID) /app/tests/

	# Errors when running under docker are saved in
	#  /app/tests/tmp/<test_with_error>.diff
	docker exec -it \
		-e POSTGRES_PASSWORD=mysecretpassword \
		-e POSTGRES_USER=postgres \
		-u $(CURRENT_UID):$(CURRENT_GID) \
		pgosm /bin/bash -c "cd tests && ./run-output-tests.sh"


help: ## Show this help
	@egrep -h '\s##\s' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m  %-30s\033[0m %s\n", $$1, $$2}'
