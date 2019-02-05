#!/bin/bash

# script adapted from https://github.com/awslabs/aws-batch-helpers/blob/master/fetch-and-run/fetch_and_run.sh

# standard function to print an error and exit with a failing return code
error_exit () {
    echo "${BASENAME} - ${1}" >&2
    exit 1
}

if [ -z "${GAPS_DATA_FILE}" ]; then
    error_exit "must pass GAPS_DATA_FILE"
fi

# check if data is stored in AWS S3
SCHEME="$(echo "${GAPS_DATA_FILE}" | cut -d: -f1)"
[ "${SCHEME}" == "s3" ] && USING_S3=true || USING_S3=false

# check for CoGAPS parameters
[ -z "${GAPS_N_THREADS}"           ] && error_exit "missing GAPS_N_THREADS"
[ -z "${GAPS_OUTPUT_FREQUENCY}"    ] && error_exit "missing GAPS_OUTPUT_FREQUENCY"
[ -z "${GAPS_TRANSPOSE_DATA}"      ] && error_exit "missing GAPS_TRANSPOSE_DATA"
[ -z "${GAPS_N_PATTERNS}"          ] && error_exit "missing GAPS_N_PATTERNS"
[ -z "${GAPS_N_ITERATIONS}"        ] && error_exit "missing GAPS_N_ITERATIONS"
[ -z "${GAPS_SEED}"                ] && error_exit "missing GAPS_SEED"
[ -z "${GAPS_SINGLE_CELL}"         ] && error_exit "missing GAPS_SINGLE_CELL"
[ -z "${GAPS_SPARSE_OPTIMIZATION}" ] && error_exit "missing GAPS_SPARSE_OPTIMIZATION"
[ -z "${GAPS_DISTRIBUTED_METHOD}"  ] && error_exit "missing GAPS_DISTRIBUTED_METHOD"
[ -z "${GAPS_N_SETS}"              ] && error_exit "missing GAPS_N_SETS"

# parse file name, need extension for CoGAPS
DIR_NAME=$(dirname -- "${GAPS_DATA_FILE}")
FILE_NAME=$(basename -- "${GAPS_DATA_FILE}")
FILE_EXT="${FILE_NAME##*.}"
FILE_BASE="${FILE_NAME%%.*}"

# check for essential programs
if [ "${USING_S3}" = true ]; then
    which aws >/dev/null 2>&1 || error_exit "Unable to find AWS CLI executable"
fi
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

IN_FILE="${GAPS_DATA_FILE}"
OUT_FILE="${FILE_BASE}-result.rds"

# copy data file to temp directory and run cogaps
if [ "${USING_S3}" = true ]; then
    echo "fetching data from s3"
    # mktemp arguments are not very portable.  We make a temporary directory with
    # portable arguments, then use a consistent filename within.
    TMPDIR="$(mktemp -d -t tmp.XXXXXXXXX)" || error_exit "Failed to create temp directory."
    IN_FILE="${TMPDIR}/${FILE_BASE}.${FILE_EXT}"
    OUT_FILE="${TMPDIR}/${FILE_BASE}-result.rds"
    install -m 0600 /dev/null "${IN_FILE}" || error_exit "Failed to create temp file."
    aws s3 cp "${GAPS_DATA_FILE}" - > "${IN_FILE}" || error_exit "Failed to download data from s3."
fi

R -e "print(packageVersion(\"CoGAPS\")); cat(CoGAPS::buildReport()); params <- new(\"CogapsParams\"); params <- CoGAPS::setDistributedParams(params, ${GAPS_N_SETS}); gapsResult <- CoGAPS::CoGAPS(data=\"${IN_FILE}\", params=params, nThreads=${GAPS_N_THREADS}, nPatterns=${GAPS_N_PATTERNS}, nIterations=${GAPS_N_ITERATIONS}, outputFrequency=${GAPS_OUTPUT_FREQUENCY}, transpose=${GAPS_TRANSPOSE_DATA}, seed=${GAPS_SEED}, singleCell=${GAPS_SINGLE_CELL}, sparseOptimization=${GAPS_SPARSE_OPTIMIZATION}, distributed=\"${GAPS_DISTRIBUTED_METHOD}\"); print(gapsResult); saveRDS(gapsResult, file =\"${OUT_FILE}\");"

if [ "${USING_S3}" = true ]; then
    echo "uploading output to s3"
    aws s3 cp "${OUT_FILE}" "${DIR_NAME}/${FILE_BASE}-result.rds"
fi

## R script (compressed into one line above)
# print(packageVersion(\"CoGAPS\"))
# cat(CoGAPS::buildReport())
# params <- new(\"CogapsParams\")
# params <- CoGAPS::setDistributedParams(params, ${GAPS_N_SETS})
# gapsResult <- CoGAPS::CoGAPS(data=\"${IN_FILE}\", params,
#     nThreads=${GAPS_N_THREADS}, nPatterns=${GAPS_N_PATTERNS},
#     nIterations=${GAPS_N_ITERATIONS},
#     outputFrequency=${GAPS_OUTPUT_FREQUENCY}, transpose=${GAPS_TRANSPOSE_DATA},
#     seed=${GAPS_SEED}, singleCell=${GAPS_SINGLE_CELL},
#     sparseOptimization=${GAPS_SPARSE_OPTIMIZATION},
#     distributed=\"${GAPS_DISTRIBUTED_METHOD}\")
# print(gapsResult)
# saveRDS(gapsResult, file =\"${OUT_FILE}\")

