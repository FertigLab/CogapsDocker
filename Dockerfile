FROM ubuntu:xenial-20190515

# install system dependencies
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get -y upgrade && \
    apt-get install -y apt-utils && \
    apt-get install -y build-essential && \
    apt-get install -y gcc && \
    apt-get install -y gcovr && \
    apt-get install -y ggcov && \
    apt-get install -y binutils

RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get install -y software-properties-common

RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get install -y apt-transport-https

RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get -y install libxml2-dev && \
    apt-get -y install libssl-dev && \
    apt-get -y install libcurl4-openssl-dev

# install R
RUN DEBIAN_FRONTEND=noninteractive add-apt-repository ppa:marutter/rrutter3.5 && \
    apt-get update && \
    apt-get install -y r-api-3.5

# install pip and jq
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get install -y python3-pip && \
    apt-get install -y jq

RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get install -y autotools-dev && \
    apt-get install -y automake

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# install AWS CLI
RUN pip3 install awscli

# copy external software
COPY external/* /usr/local/bin/external/

# install valgrind
RUN cd /usr/local/bin/external && \
    tar -xf valgrind-3.15.0.tar.bz2 && \
    cd valgrind-3.15.0 && \
    ./autogen.sh && \
    ./configure && \
    make && \
    make install

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

# install latest version of CoGAPS from github
RUN echo "force rebuild 12" && \
   R -e 'BiocManager::install("FertigLab/CoGAPS", dependencies=FALSE)' && \
   R -e 'packageVersion("CoGAPS")'

# set up environment
ENV PATH "$PATH:/usr/local/bin/cogaps"
COPY src/* /usr/local/bin/cogaps/

# call run script
CMD ["/usr/local/bin/cogaps/aws_cogaps.sh"]


