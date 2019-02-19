library(CoGAPS)
args <- commandArgs(TRUE)
fileName <- args[1]
paramName <- args[2]
params <- readRDS(fileName)
cat(slot(params, paramName))
