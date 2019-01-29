FROM r-base:3.5.2

ENV DEBIAN_FRONTEND noninteractive

# install system dependencies
RUN apt-get update && \
    apt-get install apt-utils -y && \
    apt-get install libxml2-dev -y && \
    apt-get install libssl-dev -y && \
    apt-get install libcurl4-openssl-dev -y && \
    rm -rf /var/lib/apt/lists/*

# install R dependencies
RUN R -e 'install.packages("remotes")'
RUN R -e 'install.packages("BiocManager")'
RUN R -e 'BiocManager::install("BiocParallel")'
RUN R -e 'BiocManager::install("cluster")'
RUN R -e 'BiocManager::install("data.table")'
RUN R -e 'BiocManager::install("methods")'
RUN R -e 'BiocManager::install("gplots")'
RUN R -e 'BiocManager::install("graphics")'
RUN R -e 'BiocManager::install("grDevices")'
RUN R -e 'BiocManager::install("RColorBrewer")'
RUN R -e 'BiocManager::install("Rcpp")'
RUN R -e 'BiocManager::install("S4Vectors")'
RUN R -e 'BiocManager::install("stats")'
RUN R -e 'BiocManager::install("tools")'
RUN R -e 'BiocManager::install("utils")'
RUN R -e 'BiocManager::install("rhdf5")'
RUN R -e 'BiocManager::install("testthat")'
RUN R -e 'BiocManager::install("knitr")'
RUN R -e 'BiocManager::install("rmarkdown")'
RUN R -e 'BiocManager::install("BiocStyle")'
RUN R -e 'BiocManager::install("Rcpp")'
RUN R -e 'BiocManager::install("SummarizedExperiment")'
RUN R -e 'BiocManager::install("SingleCellExperiment")'
RUN R -e 'BiocManager::install("optparse")'

# install latest version from github
RUN echo "force rebuild 2" && \
    R -e 'BiocManager::install("FertigLab/CoGAPS", dependencies=FALSE)' && \
    R -e 'packageVersion("CoGAPS")'

# set up environment
ENV PATH "$PATH:/usr/local/bin/cogaps"
COPY src/* /usr/local/bin/cogaps/

# call run script
ENTRYPOINT ["Rscript", "/usr/local/bin/cogaps/run_cogaps.R"]


