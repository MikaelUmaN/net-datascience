FROM ubuntu:22.04

ENV DEBIAN_FRONTEND noninteractive
ENV PATH="/opt/conda/bin:${PATH}"
ARG PATH="/opt/conda/bin:${PATH}"

USER root

# apt packages
RUN apt update && apt install -y sudo htop build-essential wget gcc git g++ \
  iputils-ping iproute2 vim texlive-latex-extra libnss3 libxss1 libx11-xcb1 libgtk-3-0 && \
  apt clean

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
    conda install python=3.11 conda-build curl && conda clean --all && \
    conda init bash

# Faster solver, using mamba libsolv underneath.
RUN conda install -n base conda-libmamba-solver
RUN conda config --set solver libmamba

RUN conda install -c pytorch "pytorch>=2,<3" torchvision cpuonly
RUN conda install "python-graphviz>=0.20.1,<2" "python-kaleido>=0.2.1,<2"
RUN conda install "jupyterlab>=4,<5" "pymc>=5,<6" "pandas>=2,<3" "numpy>1,<2" "numpyro<2" \
    "seaborn<2" "plotly>=5,<6" "spacy>=3,<4" numba>=0.57.1 "scikit-learn>=1,<2" \
    "pyarrow>=13,<14" "pytest>=7,<8" "aiofiles>=23,<24" "aiohttp>=3,<4" \
    "python-confluent-kafka>=2,<3" "nodejs>=18,<19" "cvxopt>=1,<2" "osqp<2" \
    "autopep8>=2,<3" "pytables>=3,<4" "python-snappy<2" "openpyxl>=3,<4" "lxml>=4,<5"
RUN conda install dask=2023.9.* dask-kubernetes=2023.9.* distributed=2023.9.*
RUN conda clean --all -y && \
    fix-permissions.sh $CONDA_DIR

# Install .NET
RUN apt update && apt install -y dotnet-sdk-7.0 dotnet-sdk-6.0

# Enable detection of running in a container
ENV \
  # Enable detection of running in a container.
  DOTNET_RUNNING_IN_CONTAINER=true \
  # Enable correct mode for dotnet watch (only mode supported in a container).
  DOTNET_USE_POLLING_FILE_WATCHER=true \
  # Skip extraction of XML docs - generally not useful within an image/container - helps performance.
  NUGET_XMLDOC_MODE=skip \
  # Opt out of telemetry.
  DOTNET_INTERACTIVE_CLI_TELEMETRY_OPTOUT=true \
  # Make F# projects default for dotnet new cli.
  DOTNET_NEW_PREFERRED_LANG=F# \
  # Skip messages on telemetry.
  DOTNET_INTERACTIVE_SKIP_FIRST_TIME_EXPERIENCE=true \
  # Used for nuget cache etc.
  DOTNET_CLI_HOME=/opt/dotnet

# Add kubectl.
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/

# Add helm.
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Create dotnet directory.
RUN mkdir /opt/dotnet
RUN fix-permissions.sh /opt/dotnet

# Numpy multithreading uses MKL lib and for it to work properly on kubernetes
# this variable needs to be set. Else numpy thinks it has access to all cores on the node.
ENV MKL_THREADING_LAYER=GNU

# Install lastest build from main branch of Microsoft.DotNet.Interactive
RUN dotnet tool install Microsoft.dotnet-interactive --tool-path ${DOTNET_CLI_HOME}/tools 

# Source code formatter
RUN dotnet tool install fantomas --tool-path ${DOTNET_CLI_HOME}/tools

ENV JUPYTER_PATH="${DOTNET_CLI_HOME}/kernels"
ENV PATH="${PATH}:${DOTNET_CLI_HOME}/tools"
RUN echo "$PATH"

# Install kernel specs
RUN mkdir ${DOTNET_CLI_HOME}/kernels
RUN dotnet interactive jupyter install --path ${DOTNET_CLI_HOME}/kernels

# Add notebook user to sudo.
RUN usermod -aG sudo ${NB_USER}
RUN echo "${NB_USER}  ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/${NB_USER}


USER $NB_USER

RUN conda init bash

WORKDIR $HOME
CMD ["start.sh", "jupyter", "lab", "--ip", "0.0.0.0"]
