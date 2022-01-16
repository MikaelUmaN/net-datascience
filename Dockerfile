FROM ubuntu:20.04

ENV DEBIAN_FRONTEND noninteractive
ENV PATH="/opt/conda/bin:${PATH}"
ARG PATH="/opt/conda/bin:${PATH}"

USER root

# apt packages
RUN apt update && apt install -y sudo build-essential wget gcc git g++ vim texlive-latex-extra && apt clean

# conda
RUN wget \
  https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh \
  && mkdir /root/.conda \
  && bash Miniconda3-latest-Linux-x86_64.sh -b -p /opt/conda \
  && rm -f Miniconda3-latest-Linux-x86_64.sh

COPY start.sh /usr/local/bin/
COPY fix-permissions.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/start.sh && chmod +x /usr/local/bin/fix-permissions.sh

ARG NB_USER="jovyan"
ARG NB_UID="1000"
ARG NB_GID="100"

ENV CONDA_DIR=/opt/conda \
  SHELL=/bin/bash \
  NB_USER=$NB_USER \
  NB_UID=$NB_UID \
  NB_GID=$NB_GID \
  PATH=$CONDA_DIR/bin:$PATH \
  HOME=/home/$NB_USER

RUN useradd -m -s /bin/bash -N -u $NB_UID $NB_USER && \
    mkdir -p $CONDA_DIR && \
    chown $NB_USER:$NB_GID $CONDA_DIR && \
    chmod g+w /etc/passwd && \
    fix-permissions.sh $HOME && \
    fix-permissions.sh $CONDA_DIR

# Create basic root python environment with proxied public channels
RUN conda config --system --add channels conda-forge && \
    conda config --add channels conda-forge && \
    conda install python=3.9 conda-build curl && conda clean --all && \
    conda init bash

RUN conda install -c pytorch pytorch=1.10.1 torchvision cpuonly && \
    conda install dask=2.30 dask-kubernetes=0.11 distributed=2.30 jupyterlab=3.2.5 jupyterhub=1.5.0 \
    nodejs=15.3.0 pandas=1.3.5 cufflinks-py=0.17.3 fastparquet=0.7.0 pyarrow=5.0.0 python-snappy=0.6.0 \
    seaborn=0.11.2 pandas-profiling=3.1.0 xlrd=2.0.1 xlwt=1.3.0 openpyxl=3.0.9 ipympl=0.8.2 \
    s3fs=0.4.2 pytest=6.2.5 h5py=3.3.0 requests_ntlm=1.1.0 awscli=1.21.6 pymc3=3.11.4 zeep=4.1.0 \
    python-kaleido=0.2.1 graphviz=2.48.0 aiofiles=0.7.0 aiohttp=3.7.4 html5lib=1.1 spacy=3.1.1 \
    python-graphviz=0.17 pyppeteer=0.2.6 blpapi=3.16.2 nbdime=3.1.1 jupyter-server-proxy=3.2.0 \
    nb_conda_kernels=2.3.1 plotly=5.5.0 bottleneck=1.3.2 pytables numba=0.54.1 && \
    fix-permissions.sh $CONDA_DIR

RUN wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
RUN dpkg -i packages-microsoft-prod.deb

# Install .NET CLI dependencies
RUN apt update && apt install -y dotnet-sdk-6.0 dotnet-sdk-5.0

# Install preview of next SDK version.
#RUN mkdir $HOME/dotnet_install && cd $HOME/dotnet_install
#RUN curl -H 'Cache-Control: no-cache' -L https://aka.ms/install-dotnet-preview -o install-dotnet-preview.sh
#RUN chmod 755 install-dotnet-preview.sh && ./install-dotnet-preview.sh

# Enable detection of running in a container
ENV \
  # Enable detection of running in a container
  DOTNET_RUNNING_IN_CONTAINER=true \
  # Enable correct mode for dotnet watch (only mode supported in a container)
  DOTNET_USE_POLLING_FILE_WATCHER=true \
  # Skip extraction of XML docs - generally not useful within an image/container - helps performance
  NUGET_XMLDOC_MODE=skip \
  # Opt out of telemetry until after we install jupyter when building the image, this prevents caching of machine id
  DOTNET_INTERACTIVE_CLI_TELEMETRY_OPTOUT=true

# Add kubectl
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/

# Add user to sudo
RUN usermod -aG sudo ${NB_USER}
RUN echo "${NB_USER}  ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/${NB_USER}

USER $NB_USER

RUN npm install -g yarn

# For diffing notebooks.
RUN nbdime config-git --enable --global

# Numpy multithreading uses MKL lib and for it to work properly on kubernetes
# this variable needs to be set. Else numpy thinks it has access to all cores on the node.
ENV MKL_THREADING_LAYER=GNU

# Install lastest build from main branch of Microsoft.DotNet.Interactive
RUN dotnet tool install -g Microsoft.dotnet-interactive --add-source "https://pkgs.dev.azure.com/dnceng/public/_packaging/dotnet-tools/nuget/v3/index.json"

ENV PATH="${PATH}:${HOME}/.dotnet/tools"
RUN echo "$PATH"

# Install kernel specs
RUN dotnet interactive jupyter install

# Make F# projects default for dotnet new cli
ENV DOTNET_NEW_PREFERRED_LANG=F#

RUN conda init bash

WORKDIR $HOME
CMD ["start.sh", "jupyter", "lab", "--ip", "0.0.0.0"]
