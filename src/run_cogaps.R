suppressMessages(suppressWarnings(library(CoGAPS)))
suppressMessages(suppressWarnings(library(optparse)))
cat("CoGAPS Version:", as.character(packageVersion("CoGAPS")), "\n")
cat(CoGAPS::buildReport())

arguments <- commandArgs(trailingOnly=TRUE)

cg_make_option <- function(param, type, def)
{
    make_option(paste("--", param, sep=""), dest=param, type=type, default=def)
}

option_list <- list(
    cg_make_option("data.file",             "character",    NULL),
    cg_make_option("n.threads",             "integer",      1),
    cg_make_option("output.frequency",      "integer",      250),
    cg_make_option("transpose.data",        "logical",      FALSE),
    cg_make_option("n.patterns",            "integer",      3),
    cg_make_option("n.iterations",          "integer",      1000),
    cg_make_option("seed",                  "integer",      42),
    cg_make_option("single.cell",           "logical",      FALSE),
    cg_make_option("sparse.optimization",   "logical",      FALSE),
    cg_make_option("distributed",           "character",    NULL),
    cg_make_option("n.sets",                "integer",      4)
)

opt_parser <- OptionParser(option_list=option_list)
opts <- parse_args(opt_parser, positional_arguments=FALSE, args=arguments)
print(opts)

params <- new("CogapsParams")
params <- setParam(params, "nPatterns", opts$n.patterns)
params <- setParam(params, "distributed", opts$distributed)
params <- setDistributedParams(params, opts$n.sets)

res <- CoGAPS(
    data=opts$data.file,
    params=params,
    nThreads=opts$n.threads,
    outputFrequency=opts$output.frequency,
    transposeData=opts$transpose.data,
    nIterations=opts$n.iterations,
    seed=opts$seed,
    singleCell=opts$single.cell,
    sparseOptimization=opts$sparse.optimization
)

print(res)
