all : docker

docker : 
	docker build -t cogaps .

test : docker
	docker run \
		-e AWS_ACCESS_KEY_ID=$(KEY_ID) \
		-e AWS_SECRET_ACCESS_KEY=$(SECRET_KEY) \
		-e AWS_BATCH_JOB_ID=docker-test-id \
		-e GAPS_DATA_FILE=s3://fertig-lab-bucket/users/tom/GIST.mtx \
		-e GAPS_N_PATTERNS=3 \
		-e GAPS_N_ITERATIONS=100 \
		-e GAPS_SEED=123 \
		-e GAPS_DISTRIBUTED_METHOD=none \
		-e GAPS_N_SETS=0 \
		-e GAPS_TRANSPOSE_DATA=TRUE \
		-e GAPS_N_THREADS=2 \
		-e GAPS_OUTPUT_FREQUENCY=50 \
		cogaps

test_profile : docker
	docker run \
		-e AWS_ACCESS_KEY_ID=$(KEY_ID) \
		-e AWS_SECRET_ACCESS_KEY=$(SECRET_KEY) \
		-e AWS_BATCH_JOB_ID=docker-test-id \
		-e GAPS_DATA_FILE=s3://fertig-lab-bucket/users/tom/GIST.mtx \
		-e GAPS_N_PATTERNS=3 \
		-e GAPS_N_ITERATIONS=100 \
		-e GAPS_SEED=123 \
		-e GAPS_DISTRIBUTED_METHOD=none \
		-e GAPS_N_SETS=0 \
		-e GAPS_TRANSPOSE_DATA=TRUE \
		-e GAPS_N_THREADS=1 \
		-e GAPS_OUTPUT_FREQUENCY=50 \
		-e GAPS_ENABLE_PROFILING=TRUE \
		cogaps

local_test :
	cd src && \
	AWS_BATCH_JOB_ID='docker-local-test-id' \
	GAPS_DATA_FILE=s3://fertig-lab-bucket/public/GIST.mtx \
	GAPS_N_THREADS=1 \
	GAPS_OUTPUT_FREQUENCY=500 \
	GAPS_TRANSPOSE_DATA=TRUE \
	GAPS_N_PATTERNS=3 \
	GAPS_N_ITERATIONS=2000 \
	GAPS_SEED=42 \
	GAPS_SINGLE_CELL=FALSE \
	GAPS_SPARSE_OPTIMIZATION=FALSE \
	GAPS_DISTRIBUTED_METHOD="none" \
	GAPS_N_SETS=0 \
	./aws_cogaps.sh && \
	 cd ..
