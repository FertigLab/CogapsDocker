#!/bin/bash

# script adapted from https://github.com/awslabs/aws-batch-helpers/blob/master/fetch-and-run/fetch_and_run.sh

# standard function to print an error and exit with a failing return code
error_exit () {
    echo "${BASENAME} - ${1}" >&2
    exit 1
}

# check for essential programs
which aws >/dev/null 2>&1 || error_exit "Unable to find AWS CLI executable"
which R >/dev/null 2>&1 || error_exit "Unable to find R executable"
which Rscript >/dev/null 2>&1 || error_exit "Unable to find Rscript executable"

# get path to R script for fetching values
THIS_SCRIPT_PATH="$( cd "$(dirname "$0")" ; pwd -P )"
GET_PARAM_R_SCRIPT=${THIS_SCRIPT_PATH}/get_param.R

# check that script is being run from AWS batch
[ -z "${AWS_BATCH_JOB_ID}" ] && error_exit "must be run from AWS batch"
echo "Running Job: ${AWS_BATCH_JOB_ID}"

# check for required parameters
[ -z "${GAPS_DATA_FILE}"        ] && error_exit "missing GAPS_DATA_FILE"
[ -z "${GAPS_PARAM_FILE}"       ] && error_exit "missing GAPS_PARAM_FILE"

# check if files are stored in AWS S3
SCHEME="$(echo "${GAPS_DATA_FILE}" | cut -d: -f1)"
[ "${SCHEME}" != "s3" ] && error_exit "data file needs to be in an s3 bucket"
SCHEME="$(echo "${GAPS_PARAM_FILE}" | cut -d: -f1)"
[ "${SCHEME}" != "s3" ] && error_exit "param file needs to be in an s3 bucket"

# parse data and parameter file names
DATA_BUCKET_NAME=$(dirname -- "${GAPS_DATA_FILE}")
DATA_FILE_NAME=$(basename -- "${GAPS_DATA_FILE}")
DATA_FILE_BASE="${DATA_FILE_NAME%%.*}"
DATA_FILE_EXT="${DATA_FILE_NAME##*.}"
PARAM_FILE_NAME=$(basename -- "${GAPS_PARAM_FILE}")

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

# copy data file to temp directory and run cogaps
echo "fetching data from s3"
LOCAL_DATA_FILE="${TMPDIR}/${DATA_FILE_NAME}"
LOCAL_PARAM_FILE="${TMPDIR}/${PARAM_FILE_NAME}"
LOCAL_OUT_FILE="${TMPDIR}/${DATA_FILE_BASE}-${AWS_BATCH_JOB_ID}-result.rds"
install -m 0600 /dev/null "${LOCAL_DATA_FILE}" || error_exit "Failed to create temp data file."
install -m 0600 /dev/null "${LOCAL_PARAM_FILE}" || error_exit "Failed to create temp param file."
aws s3 cp "${GAPS_DATA_FILE}" - > "${LOCAL_DATA_FILE}" || error_exit "Failed to download data file from s3."
aws s3 cp "${GAPS_PARAM_FILE}" - > "${LOCAL_PARAM_FILE}" || error_exit "Failed to download param file from s3."

# check for optional parameters, use param file if not provided
if [ -z "${GAPS_N_PATTERNS}" ]; then
    GAPS_N_PATTERNS="$(Rscript ${GET_PARAM_R_SCRIPT} ${LOCAL_PARAM_FILE} nPatterns)"
fi

if [ -z "${GAPS_N_ITERATIONS}" ]; then
    GAPS_N_ITERATIONS="$(Rscript ${GET_PARAM_R_SCRIPT} ${LOCAL_PARAM_FILE} nIterations)"
fi

if [ -z "${GAPS_N_SETS}" ]; then
    GAPS_N_SETS="$(Rscript ${GET_PARAM_R_SCRIPT} ${LOCAL_PARAM_FILE} nSets)"
fi

if [ -z "${GAPS_SEED}" ]; then
    GAPS_SEED="$(Rscript ${GET_PARAM_R_SCRIPT} ${LOCAL_PARAM_FILE} seed)"
fi

# check for optional parameters that aren't in param file
if [ -z "${GAPS_N_THREADS}" ]; then
    GAPS_N_THREADS="1"
fi

if [ -z "${GAPS_OUTPUT_FREQUENCY}" ]; then
    GAPS_OUTPUT_FREQUENCY="2500"
fi

if [ -z "${GAPS_TRANSPOSE_DATA}" ]; then
    GAPS_TRANSPOSE_DATA="FALSE"
fi

if [ -z "${GAPS_DISTRIBUTED_METHOD}" ]; then
    GAPS_DISTRIBUTED_METHOD="none"
fi

# get log stream URL 
LOG_STREAM_NAME=`aws batch describe-jobs --jobs ${AWS_BATCH_JOB_ID} --region us-east-2 --output json | jq '. | .jobs[0].container.logStreamName'`
echo "Log Stream Name: ${LOG_STREAM_NAME}"

# run cogaps
Rscript -e "\
    args <- commandArgs(trailingOnly=TRUE); \
    library(CoGAPS); \
    print(packageVersion(\"CoGAPS\")); \
    cat(CoGAPS::buildReport()); \
    params <- readRDS(\"${LOCAL_PARAM_FILE}\"); \
    params <- setParam(params, \"nPatterns\", ${GAPS_N_PATTERNS}); \
    params <- setDistributedParams(params, nSets=${GAPS_N_SETS}); \
    params <- setParam(params, \"distributed\", \"${GAPS_DISTRIBUTED_METHOD}\"); \
    nThreads <- ${GAPS_N_THREADS}; \
    if (is.null(params@distributed) && nThreads == 1) \
        nThreads <- parallel::detectCores(); \
    gapsResult <- CoGAPS::CoGAPS(data=\"${LOCAL_DATA_FILE}\", \
        params=params, nIterations=${GAPS_N_ITERATIONS}, seed=${GAPS_SEED}, \
        nThreads=nThreads, outputFrequency=${GAPS_OUTPUT_FREQUENCY}, \
        transposeData=${GAPS_TRANSPOSE_DATA}); \
    gapsResult@metadata\$logStreamName <- args[1]; \
    print(gapsResult); \
    saveRDS(gapsResult, file =\"${LOCAL_OUT_FILE}\"); \
" ${LOG_STREAM_NAME}

# upload results to same s3 bucket that data was in
echo "uploading output to s3"
aws s3 cp "${LOCAL_OUT_FILE}" "${DATA_BUCKET_NAME}/${DATA_FILE_BASE}-${AWS_BATCH_JOB_ID}-result.rds"
