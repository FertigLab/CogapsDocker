docker: 
	docker build -t cogaps .

test:
	docker run \
		-e AWS_ACCESS_KEY_ID=$(KEY_ID) \
		-e AWS_SECRET_ACCESS_KEY=$(SECRET_KEY) \
		-e AWS_BATCH_JOB_ID='docker-test-id' \
		-e GAPS_DATA_FILE='s3://fertig-lab-bucket-gist/GIST.tsv' \
		-e GAPS_PARAM_FILE='s3://fertig-lab-bucket-gist/gist_params.rds' \
		cogaps

local_test:
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
