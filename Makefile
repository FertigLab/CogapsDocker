

build:
	docker build -t cogaps .

run:
	docker run $(ARGS) cogaps

ls:
	docker images
