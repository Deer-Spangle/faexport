PROJECT = furaffinity-api
DOCKER_HUB_NAME = deerspangle/furaffinity-api
CONTAINER_NAME = fa_api
REDIS_CONTAINER = redis_container
VERSION = "2020.02.0"

fa_cookie:
	ifndef ENV_VAR
		@echo Warning: FA_COOKIE isn\'t defined\; continue? [Y/n]
		@read line; if [ $$line == "n" ]; then echo aborting; exit 1 ; fi
	endif

build:
	docker build -t $(PROJECT) .

run: build fa_cookie
	docker run \
	-e FA_COOKIE="$(FA_COOKIE)" \
	-e REDIS_URL="redis://redis:6379/0" \
	-p 80:9292 \
	--name $(CONTAINER_NAME) \
	--link redis_container:redis \
	$(PROJECT)

start: fa_cookie
	docker run \
	-e FA_COOKIE="$(FA_COOKIE)" \
	-e REDIS_URL="redis://redis:6379/0" \
	-p 80:9292 \
	--name $(CONTAINER_NAME) \
	--link $(REDIS_CONTAINER):redis -d \
	$(PROJECT)

start_standalone: fa_cookie
	docker run \
	-e FA_COOKIE="$(FA_COOKIE)" \
	-p 80:9292 \
	--name $(CONTAINER_NAME) -d \
	$(PROJECT)

deploy: fa_cookie
	docker run \
	-e FA_COOKIE="$(FA_COOKIE)" \
	-e REDIS_URL="redis://redis:6379/0" \
	-p 80:9292 \
	--restart=always \
	--name fa_api \
	--link $(REDIS_CONTAINER):redis \
	$(DOCKER_HUB_NAME)

publish: build
	docker push $(PROJECT) $(DOCKER_HUB_NAME):$(VERSION)

stop:
	docker stop $(PROJECT)

clean:
	docker kill -s 9 $(PROJECT) || true
	docker rm $(PROJECT) || true
	docker rmi -f $(PROJECT) || true
	rm -rf venv
