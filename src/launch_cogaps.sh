#!/bin/bash

# script adapted from https://github.com/awslabs/aws-batch-helpers/blob/master/fetch-and-run/fetch_and_run.sh

# Standard function to print an error and exit with a failing return code
error_exit () {
    echo "${BASENAME} - ${1}" >&2
    exit 1
}

# make sure URL was passed
if [ -z "${GAPS_DATA_FILE_S3_URL}" ]; then
    error_exit "No GAPS_DATA_FILE_S3_URL provided"
fi

# make sure URL is valid
scheme="$(echo "${GAPS_DATA_FILE_S3_URL}" | cut -d: -f1)"
if [ "${scheme}" != "s3" ]; then
    error_exit "error in GAPS_DATA_FILE_S3_URL, expecting URL starting with s3://"
fi

# check for CoGAPS parameters
[ -z "${GAPS_N_THREADS}"           ] && error_exit "missing GAPS_N_THREADS"
[ -z "${GAPS_OUTPUT_FREQUENCY}"    ] && error_exit "missing GAPS_OUTPUT_FREQUENCY"
#[ -z "${GAPS_TRANSPOSE_DATA}"      ] && error_exit "missing GAPS_TRANSPOSE_DATA"
[ -z "${GAPS_N_PATTERNS}"          ] && error_exit "missing GAPS_N_PATTERNS"
[ -z "${GAPS_N_ITERATIONS}"        ] && error_exit "missing GAPS_N_ITERATIONS"
#[ -z "${GAPS_SEED}"                ] && error_exit "missing GAPS_SEED"
#[ -z "${GAPS_SINGLE_CELL}"         ] && error_exit "missing GAPS_SINGLE_CELL"
#[ -z "${GAPS_SPARSE_OPTIMIZATION}" ] && error_exit "missing GAPS_SPARSE_OPTIMIZATION"
#[ -z "${GAPS_DISTRIBUTED_METHOD}"  ] && error_exit "missing GAPS_DISTRIBUTED_METHOD"
#[ -z "${GAPS_N_SETS}"              ] && error_exit "missing GAPS_N_SETS"

# parse file name, need extension for CoGAPS
FILE_NAME=$(basename -- "$GAPS_DATA_FILE_S3_URL")
FILE_EXT="${FILE_NAME##*.}"
FILE_BASE="${FILE_NAME%%.*}"

# check for essential programs
which aws >/dev/null 2>&1 || error_exit "Unable to find AWS CLI executable"
which R >/dev/null 2>&1 || error_exit "Unable to find R executable"

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
TMPFILE="${TMPDIR}/$FILE_BASE-temp.$FILE_EXT"
install -m 0600 /dev/null "${TMP_IN_FILE}" || error_exit "Failed to create temp file."

# copy data file to temp directory and run cogaps
aws s3 cp "${GAPS_DATA_FILE_S3_URL}" - > "${TMP_IN_FILE}" || error_exit "Failed to download S3 script."
R -e "gapsResult <- CoGAPS::CoGAPS(data=\"${TMP_IN_FILE}\", nThreads=${GAPS_N_THREADS}, nPatterns=${GAPS_N_PATTERNS}, nIterations=${GAPS_N_ITERATIONS}, outputFrequency=${GAPS_OUTPUT_FREQUENCY}); print(res); save(gapsResult, file=\"${TMP_OUT_FILE}\");"

aws sc cp "${TMP_OUT_FILE}" s3://fertig-lab-bucket-1/gapsResult.RData


