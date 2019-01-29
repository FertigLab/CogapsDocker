

build:
	docker build -t cogaps_docker .

run:
	docker run cogaps_docker $(ARGS)

ls:
	docker images
