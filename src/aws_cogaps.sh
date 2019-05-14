#!/bin/bash

# script adapted from https://github.com/awslabs/aws-batch-helpers/blob/master/fetch-and-run/fetch_and_run.sh

#################################### Setup #####################################

# standard function to print an error and exit with a failing return code
error_exit () {
    echo "${BASENAME} - ${1}" >&2
    exit 1
}

# check that script is being run from AWS batch
[ -z "${AWS_BATCH_JOB_ID}" ] && error_exit "must be run from AWS batch"
echo "Running Job: ${AWS_BATCH_JOB_ID}"

# check for essential programs
which aws >/dev/null 2>&1 || error_exit "Unable to find AWS CLI"
which R >/dev/null 2>&1 || error_exit "Unable to find R"
which Rscript >/dev/null 2>&1 || error_exit "Unable to find Rscript"
which jq >/dev/null 2>&1 || error_exit "Unable to find jq"

# get log stream URL 
LOG_STREAM_NAME=`aws batch describe-jobs --jobs ${AWS_BATCH_JOB_ID} --region us-east-2 --output json | jq '. | .jobs[0].container.logStreamName'`
echo "Log Stream Name: ${LOG_STREAM_NAME}"

# Create a temporary directory to hold the downloaded contents, and make sure
# it's removed later, unless the user set KEEP_BATCH_FILE_CONTENTS.
cleanup () {
   if [ -z "${KEEP_BATCH_FILE_CONTENTS}" ] \
     && [ -n "${TMPDIR}" ] \
     && [ "${TMPDIR}" != "/" ]; then
      rm -r "${TMPDIR}"
   fi
}
trap 'cleanup' EXIT HUP INT QUIT TERM

# mktemp arguments are not very portable.  We make a temporary directory with
# portable arguments, then use a consistent filename within.
TMPDIR="$(mktemp -d -t tmp.XXXXXXXXX)" || error_exit "Failed to create temp directory."

################################### Get Data ###################################

# check if file parameter exists
[ -z "${GAPS_DATA_FILE}" ] && error_exit "missing GAPS_DATA_FILE"

# check if file is stored in AWS S3
SCHEME="$(echo "${GAPS_DATA_FILE}" | cut -d: -f1)"
[ "${SCHEME}" != "s3" ] && error_exit "data file needs to be in an s3 bucket"

# parse file name
DATA_BUCKET_NAME=$(dirname -- "${GAPS_DATA_FILE}")
DATA_FILE_NAME=$(basename -- "${GAPS_DATA_FILE}")
DATA_FILE_BASE="${DATA_FILE_NAME%%.*}"
DATA_FILE_EXT="${DATA_FILE_NAME##*.}"

# create name for local output from CoGAPS
LOCAL_OUT_FILE="${TMPDIR}/${DATA_FILE_BASE}-${AWS_BATCH_JOB_ID}-result.rds"

# copy file to temp directory
LOCAL_DATA_FILE="${TMPDIR}/${DATA_FILE_NAME}"
install -m 0600 /dev/null "${LOCAL_DATA_FILE}" || error_exit "Failed to create temp data file."
echo "Fetching data from s3"
aws s3 cp "${GAPS_DATA_FILE}" - > "${LOCAL_DATA_FILE}" || error_exit "Failed to download data file from s3."

############################## Get Parameter File ##############################

if [ ! -z "${GAPS_PARAM_FILE}" ]; then

    # check if file is stored in AWS S3
    SCHEME="$(echo "${GAPS_PARAM_FILE}" | cut -d: -f1)"
    [ "${SCHEME}" != "s3" ] && error_exit "param file needs to be in an s3 bucket"

    # parse file name
    PARAM_FILE_NAME=$(basename -- "${GAPS_PARAM_FILE}")

    # copy file to temp directory
    LOCAL_PARAM_FILE="${TMPDIR}/${PARAM_FILE_NAME}"
    install -m 0600 /dev/null "${LOCAL_PARAM_FILE}" || error_exit "Failed to create temp param file."
    echo "Fetching parameter file from s3"
    aws s3 cp "${GAPS_PARAM_FILE}" - > "${LOCAL_PARAM_FILE}" || error_exit "Failed to download param file from s3."

fi

################################## Run COGAPS ##################################

# run cogaps with parameters
Rscript run_cogaps.R \
    --data.file=${LOCAL_DATA_FILE} \
    --output.file=${LOCAL_OUT_FILE} \
    --param.file=${LOCAL_PARAM_FILE} \
    --num.patterns=${GAPS_N_PATTERNS} \
    --num.iterations=${GAPS_N_ITERATIONS} \
    --seed=${GAPS_SEED} \
    --distributed.method=${GAPS_DISTRIBUTED_METHOD} \
    --num.sets=${GAPS_N_SETS} \
    --transpose.data=${GAPS_TRANSPOSE_DATA} \
    --num.threads=${GAPS_N_THREADS} \
    --ouput.frequency=${GAPS_OUTPUT_FREQUENCY} \
    --github.tag=${GAPS_GITHUB_TAG} \
    --aws.log.stream.name=${LOG_STREAM_NAME}

# upload results to same s3 bucket that data was in
echo "uploading output to s3"
aws s3 cp "${LOCAL_OUT_FILE}" "${DATA_BUCKET_NAME}/${DATA_FILE_BASE}-${AWS_BATCH_JOB_ID}-result.rds"
