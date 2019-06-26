FROM ubuntu:xenial-20190515

# install system dependencies
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get -y upgrade && \
    apt-get install -y apt-utils && \
    apt-get install -y build-essential && \
    apt-get install -y software-properties-common && \
    apt-get install -y apt-transport-https && \
    apt-get install -y libxml2-dev && \
    apt-get install -y libssl-dev && \
    apt-get install -y libcurl4-openssl-dev && \
    apt-get install -y python3-pip && \
    apt-get install -y jq

# install R
RUN DEBIAN_FRONTEND=noninteractive add-apt-repository ppa:marutter/rrutter3.5 && \
    apt-get update && \
    apt-get install -y r-api-3.5

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# install AWS CLI
RUN pip3 install awscli

# install R dependencies
RUN R -e 'install.packages("remotes", repos="http://cran.rstudio.com/")'
RUN R -e 'install.packages("BiocManager", repos="http://cran.rstudio.com/")'
RUN R -e 'BiocManager::install("BiocParallel", site_repository=c("http://cran.rstudio.com/"))'
RUN R -e 'BiocManager::install("cluster", site_repository=c("http://cran.rstudio.com/"))'
RUN R -e 'BiocManager::install("gplots", site_repository=c("http://cran.rstudio.com/"))'
RUN R -e 'BiocManager::install("graphics", site_repository=c("http://cran.rstudio.com/"))'
RUN R -e 'BiocManager::install("grDevices", site_repository=c("http://cran.rstudio.com/"))'
RUN R -e 'BiocManager::install("RColorBrewer", site_repository=c("http://cran.rstudio.com/"))'
RUN R -e 'BiocManager::install("Rcpp", site_repository=c("http://cran.rstudio.com/"))'
RUN R -e 'BiocManager::install("S4Vectors", site_repository=c("http://cran.rstudio.com/"))'
RUN R -e 'BiocManager::install("stats", site_repository=c("http://cran.rstudio.com/"))'
RUN R -e 'BiocManager::install("tools", site_repository=c("http://cran.rstudio.com/"))'
RUN R -e 'BiocManager::install("utils", site_repository=c("http://cran.rstudio.com/"))'
RUN R -e 'BiocManager::install("rhdf5", site_repository=c("http://cran.rstudio.com/"))'
RUN R -e 'BiocManager::install("testthat", site_repository=c("http://cran.rstudio.com/"))'
RUN R -e 'BiocManager::install("knitr", site_repository=c("http://cran.rstudio.com/"))'
RUN R -e 'BiocManager::install("rmarkdown", site_repository=c("http://cran.rstudio.com/"))'
RUN R -e 'BiocManager::install("BiocStyle", site_repository=c("http://cran.rstudio.com/"))'
RUN R -e 'BiocManager::install("Rcpp", site_repository=c("http://cran.rstudio.com/"))'
RUN R -e 'BiocManager::install("SummarizedExperiment", site_repository=c("http://cran.rstudio.com/"))'
RUN R -e 'BiocManager::install("SingleCellExperiment", site_repository=c("http://cran.rstudio.com/"))'
RUN R -e 'BiocManager::install("optparse", site_repository=c("http://cran.rstudio.com/"))'

# install latest version of CoGAPS from github
RUN echo "force rebuild 15" && \
    R -e 'BiocManager::install("FertigLab/CoGAPS", dependencies=FALSE)' && \
    R -e 'packageVersion("CoGAPS")'

# set up environment
ENV PATH "$PATH:/usr/local/bin/cogaps"
COPY src/* /usr/local/bin/cogaps/

# call run script
CMD ["/usr/local/bin/cogaps/aws_cogaps.sh"]


