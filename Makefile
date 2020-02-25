PROJECT = furaffinity-api
DOCKER_HUB_NAME = deerspangle/furaffinity-api
CONTAINER_NAME = fa_api
REDIS_CONTAINER = redis_container

FA_COOKIE:
	ifndef FA_COOKIE
		@echo Warning: FA_COOKIE isn\'t defined\; continue? [Y/n]
		@read line; if [ $$line == "n" ]; then echo aborting; exit 1 ; fi
	endif

VERSION:
	ifndef VERSION
		@echo Warning: VERSION isn\'t defined\; continue? [Y/n]
		@read line; if [ $$line == "n" ]; then echo aborting; exit 1 ; fi
	endif

docker_build:
	docker build -t $(PROJECT) .

docker_run: docker_build FA_COOKIE
	docker run \
	-e FA_COOKIE="$(FA_COOKIE)" \
	-e REDIS_URL="redis://redis:6379/0" \
	-p 80:9292 \
	--name $(CONTAINER_NAME) \
	--link redis_container:redis \
	$(PROJECT)

docker_run_standalone: docker_build FA_COOKIE
	docker run \
	-e FA_COOKIE="$(FA_COOKIE)" \
	-p 80:9292 \
	--name $(CONTAINER_NAME) -d \
	$(PROJECT)

install:
	sudo apt-get install redis-server ruby ruby-dev
	sudo gem install bundler
	bundle install

run: install
	bundle exec rackup config.ru

publish: clean docker_build VERSION
	git tag $(VERSION)
	git push origin --tags
	docker tag $(PROJECT) $(DOCKER_HUB_NAME):$(VERSION)
	docker push $(DOCKER_HUB_NAME):$(VERSION)
	docker tag $(PROJECT) $(DOCKER_HUB_NAME):latest
	docker push $(DOCKER_HUB_NAME):latest

deploy: FA_COOKIE
	FA_COOKIE=$(FA_COOKIE) docker-compose up

deploy_bypass: FA_COOKIE
	FA_COOKIE=$(FA_COOKIE) docker-compose -f docker-compose.yml -f docker-compose-cfbypass.yml up

clean_docker:
	docker kill -s 9 $(PROJECT) || true
	docker rm $(PROJECT) || true
	docker rmi -f $(PROJECT) || true

clean: clean_docker
	git reset -- .
	git checkout -- .
	git clean -df
	rm -rf venv
