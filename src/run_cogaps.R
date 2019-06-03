library(getopt)
library(optparse)

# these are the allowed command line arguments, the default value is always
# NULL and it is up to the script to handle missing arguments and set other
# default values
arguments <- commandArgs(trailingOnly=TRUE)
option_list <- list(
    make_option("--data.file", dest="data.file", default=NULL),
    make_option("--output.file", dest="output.file", default=NULL),
    make_option("--param.file", dest="param.file", default=NULL),
    make_option("--num.patterns", type="integer", dest="num.patterns", default=NULL),
    make_option("--num.iterations", type="integer", dest="num.iterations", default=NULL),
    make_option("--seed", type="integer", dest="seed", default=NULL),
    make_option("--distributed.method", dest="distributed.method", default=NULL),
    make_option("--num.sets", type="integer", dest="num.sets", default=NULL),
    make_option("--transpose.data", type="logical", dest="transpose.data", default=NULL),
    make_option("--num.threads", type="integer", dest="num.threads", default=NULL),
    make_option("--output.frequency", type="integer", dest="output.frequency", default=NULL),
    make_option("--github.tag", dest="github.tag", default=NULL),
    make_option("--aws.log.stream.name", dest="aws.log.stream.name", default=NULL)
)

# parse command line arguments, remove the help argument for nicer printing
opt <- parse_args(OptionParser(option_list=option_list),
    positional_arguments=FALSE, args=arguments)
opts <- opt$options
opts$help <- NULL

# set empty string arguments as NULL, so that you can call this script with
# potentially empty environment variables,
# i.e. `Rscript run_cogaps.R --data.file=${INPUT_FILE}`
for (option in names(opts))
{
    if (opts[option] == "")
        opts[option] <- NULL
}

# show the processed list of command line arguments
if (length(opts) == 0)
    stop("No command line options given")
cat("Command line options processed:\n")
print(opts)

# make sure required arguments are given
if (is.null(opts$data.file))
    stop("Must provide --data.file")
if (is.null(opts$output.file))
    stop("Must provide --output.file")
if (is.null(opts$num.patterns) & is.null(opts$param.file))
    stop("Must provide --num.patterns if not providing --param.file")
if (is.null(opts$num.iterations) & is.null(opts$param.file))
    stop("Must provide --num.iterations if not providing --param.file")
    
# check if a specific version of CoGAPS is requested, try to install it
if (!is.null(opts$github.tag))
{
    cat("Trying to load CoGAPS (", opts$github.tag, ") from github\n", sep="")
    BiocManager::install("FertigLab/CoGAPS", ask=FALSE, ref=opts$github.tag)
}

# print information about the installed version of CoGAPS
cat("Loading CoGAPS\n")
library(CoGAPS)
cat("Information about currently installed version of CoGAPS\n")
cat("Version:", as.character(packageVersion("CoGAPS")), "\n")
cat(CoGAPS::buildReport())

# process parameter file if given
params <- CogapsParams()
if (!is.null(opts$param.file))
    params <- readRDS(opts$param.file)

# command line arguments take precedent over parameter file
setParamValue <- function(params, name, value)
{
    if (!is.null(value))
        params <- setParam(params, name, value)
    return(params)
}
params <- setParamValue(params, "nPatterns", opts$num.patterns)
params <- setParamValue(params, "nIterations", opts$num.iterations)
params <- setParamValue(params, "seed", opts$seed)
params <- setParamValue(params, "distributed", opts$distributed.method)

# special command line arguments
if (!is.null(opts$num.sets))
    params <- setDistributedParams(params, nSets=opts$num.sets)

# some arguments aren't in the parameter file, set defaults here
getValue <- function(value, default) ifelse(is.null(value), default, value)
transposeData <- getValue(opts$transpose.data, default=FALSE)
nThreads <- getValue(opts$num.threads, default=1)
outputFrequency <- getValue(opts$output.frequency, default=1000)

# can only use one thread when running distributed cogaps
if (!is.null(params@distributed))
    nThreads <- 1

# run cogaps
gapsResult <- CoGAPS(data=opts$data.file, params=params, nThreads=nThreads,
    transposeData=transposeData, outputFrequency=outputFrequency)

# add platform specific metadata
if (!is.null(opts$aws.log.stream.name))
    gapsResult@metadata$logStreamName <- opts$aws.log.stream.name

# display and save result
print(gapsResult)
saveRDS(gapsResult, file=opts$output.file)