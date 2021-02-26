FROM ubuntu:20.04

ENV PATH="/opt/conda/bin:${PATH}"
ARG PATH="/opt/conda/bin:${PATH}"

USER root

# apt packages
RUN apt update && apt install -y sudo wget gcc git g++ vim && apt clean

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
    conda install python=3.8.5 conda-build curl && conda clean --all && \
    conda init bash

RUN conda update conda && \
    conda install nodejs=15.3.0 jupyterlab=3.0.5 jupyterhub=1.1.0 nb_conda_kernels \
      pandas cufflinks-py ipykernel dask=2.30 dask-kubernetes=0.11 \
      distributed=2.30 fastparquet pyarrow python-snappy pymc3 s3fs seaborn python-kaleido && \    
    conda install -c pytorch pytorch=1.6 torchvision cpuonly && \
    fix-permissions.sh $CONDA_DIR

RUN wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
RUN dpkg -i packages-microsoft-prod.deb

ARG DEBIAN_FRONTEND=noninteractive

# Install .NET CLI dependencies
RUN apt-get update; \
  apt-get install -y apt-transport-https && \
  apt-get update && \
  apt-get install -y dotnet-sdk-5.0

# Legacy dependencies
RUN apt-get update && apt-get install -y dotnet-sdk-3.1

# Install preview of next SDK version.
#RUN mkdir $HOME/dotnet_install && cd $HOME/dotnet_install
#RUN curl -H 'Cache-Control: no-cache' -L https://aka.ms/install-dotnet-preview -o install-dotnet-preview.sh
#RUN chmod 755 install-dotnet-preview.sh && ./install-dotnet-preview.sh

# Enable detection of running in a container
ENV DOTNET_RUNNING_IN_CONTAINER=true \
    # Enable correct mode for dotnet watch (only mode supported in a container)
    DOTNET_USE_POLLING_FILE_WATCHER=true \
    # Skip extraction of XML docs - generally not useful within an image/container - helps performance
    NUGET_XMLDOC_MODE=skip \
    # Opt out of telemetry until after we install jupyter when building the image, this prevents caching of machine id
    DOTNET_TRY_CLI_TELEMETRY_OPTOUT=true

# Add kubectl
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/

# Add user to sudo
RUN usermod -aG sudo ${NB_USER}
RUN echo "${NB_USER}  ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/${NB_USER}

USER $NB_USER

RUN npm install -g yarn

# Numpy multithreading uses MKL lib and for it to work properly on kubernetes
# this variable needs to be set. Else numpy thinks it has access to all cores on the node.
ENV MKL_THREADING_LAYER=GNU

RUN conda install jupyter-server-proxy && \
    jupyter labextension install jupyterlab-plotly@4.14.3 &&  \
    jupyter labextension install @jupyter-widgets/jupyterlab-manager && \
    jupyter serverextension enable --sys-prefix jupyter_server_proxy

# Install lastest build from main branch of Microsoft.DotNet.Interactive
RUN dotnet tool install -g Microsoft.dotnet-interactive --add-source "https://pkgs.dev.azure.com/dnceng/public/_packaging/dotnet-tools/nuget/v3/index.json"

RUN dotnet tool install -g fake-cli
RUN dotnet tool install -g paket

ENV PATH="${PATH}:${HOME}/.dotnet/tools"
RUN echo "$PATH"

# Install kernel specs
RUN dotnet interactive jupyter install

# Make F# projects default for dotnet new cli
ENV DOTNET_NEW_PREFERRED_LANG=F#

RUN conda init bash

WORKDIR $HOME
CMD ["start.sh", "jupyter", "lab", "--ip", "0.0.0.0"]
