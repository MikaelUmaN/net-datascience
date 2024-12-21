FROM ubuntu:24.04

USER root

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/opt/conda/bin:${PATH}"
ARG PATH="/opt/conda/bin:${PATH}"

# apt packages
RUN apt update && apt install -y sudo htop build-essential wget gcc git g++ curl lsof \
  iputils-ping iproute2 vim texlive-latex-extra libnss3 libxss1 libx11-xcb1 libgtk-3-0 \
  libtiff5-dev && \
  apt clean

COPY start.sh /usr/local/bin/
COPY fix-permissions.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/start.sh && chmod +x /usr/local/bin/fix-permissions.sh

ARG NB_USER=jovyan
ARG NB_UID=1000
ARG NB_GID=100

ENV CONDA_DIR=/opt/conda \
    SHELL=/bin/bash \
    NB_USER=$NB_USER \
    NB_UID=$NB_UID \
    NB_GID=$NB_GID
ENV PATH=$CONDA_DIR/bin:$PATH \
    HOME=/home/$NB_USER

# conda
RUN wget \
  https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh \
  && mkdir /root/.conda \
  && bash Miniconda3-latest-Linux-x86_64.sh -b -p $CONDA_DIR \
  && rm -f Miniconda3-latest-Linux-x86_64.sh

# Remove default user (ubuntu) if it exists.
RUN if id $NB_UID &>/dev/null; then \
  echo "Deleting user with UID ${NB_UID}}"; \
  userdel -r $(getent passwd $NB_UID | cut -d: -f1); \
  fi

RUN useradd -m -s /bin/bash -N -u $NB_UID $NB_USER && \
  chmod g+w /etc/passwd

# Add notebook user to sudo.
RUN usermod -aG sudo ${NB_USER}
RUN echo "${NB_USER}  ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/${NB_USER}

# Create basic root python environment.
RUN conda install python=3.12 conda-build curl && \
    conda clean --all && \
    conda init bash

# Transfer ownership of /opt/conda to jovyan. Not a good idea for multi-user settings or other complex scenarios but works for our dev image.
RUN chown -R ${NB_USER}:${NB_GID} ${CONDA_DIR}

USER $NB_USER

# Reinstalling libarchive due to known issue: https://github.com/conda/conda-libmamba-solver/issues/283
# numexpr set to >= 2.8.4 after warning from pandas.
# Last conda install line consists dev and build validation libraries and are purposely not restricted by version.
RUN conda install libarchive --force-reinstall
RUN conda install -c pytorch "pytorch>=2,<3" torchvision cpuonly 
RUN conda install -c conda-forge dask dask-kubernetes distributed
RUN conda install -c conda-forge "jupyterlab>=4,<5" "pymc>=5,<6" "pandas>=2,<3" "numexpr>=2.8.4" "numpy>=1,<3" "numpyro<2" \
    "seaborn<2" "plotly>=5,<6" "matplotlib>=3,<4" "spacy>=3,<4" "numba>=0.57.1" "scikit-learn>=1,<2" \
    "pyarrow>=15.0.2,<17" "aiofiles>=23,<24" "aiohttp>=3,<4" \
    "python-confluent-kafka>=2,<3" "nodejs>=18,<19" "cvxopt>=1,<2" "osqp<2" \
    "pytables>=3,<4" "python-snappy<2" "openpyxl>=3,<4" "lxml>=5,<6" "marimo<=2" \
    "python-graphviz>=0.20.1,<2" "python-kaleido>=0.2.1,<2" \
    "orjson<4" "fastapi<2" "uvicorn<2" "zeep<5" "slack-sdk<4" "more-itertools<11" \
    "retrying<2" "avro<2" "fastavro<2" "python-confluent-kafka<3" "cmreshandler<2" "s3fs<2024.3" "aiobotocore<3"
RUN conda install -c conda-forge pytest autopep8 ruff mypy ipywidgets && \
    # Matplotlib uses pillow which uses libtiff5. Without reinstall it does not find libtiff.
    pip install pillow --force && \
    conda clean --all -y

USER root

# node.js LTS from nvm (node version manager)
ENV NVM_DIR=/opt/nvm
RUN mkdir -p $NVM_DIR
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
RUN bash -c "source $NVM_DIR/nvm.sh && nvm install --lts"

# Kubectl.
# If the folder `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
# sudo mkdir -p -m 755 /etc/apt/keyrings
ARG KUBECTLVER=1.29
RUN curl -fsSL https://pkgs.k8s.io/core:/stable:/v${KUBECTLVER}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
RUN echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBECTLVER}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
RUN apt-get update && apt-get install -y kubectl

# Helm.
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# AWS CLI.
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install

# Install dotnet.
RUN apt install -y dotnet-sdk-8.0

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
  DOTNET_CLI_HOME=/opt/dotnet \
  # Install path for dotnet. 
  # The default location on Ubuntu 22.04 is /usr/share/dotnet (when installed from packages.microsoft.com) or /usr/lib/dotnet (when installed from Jammy feed). 
  DOTNET_ROOT=/usr/lib/dotnet

# Create dotnet directory.
RUN mkdir $DOTNET_CLI_HOME

# Install lastest build from main branch of Microsoft.DotNet.Interactive
RUN dotnet tool install Microsoft.dotnet-interactive --tool-path ${DOTNET_CLI_HOME}/tools 

# Source code formatter
RUN dotnet tool install fantomas --tool-path ${DOTNET_CLI_HOME}/tools

ENV JUPYTER_PATH="${DOTNET_CLI_HOME}"
ENV PATH="${PATH}:${DOTNET_CLI_HOME}/tools"
RUN echo "$PATH"

# Install kernel specs
RUN mkdir ${DOTNET_CLI_HOME}/kernels
RUN dotnet interactive jupyter install --path ${DOTNET_CLI_HOME}/kernels

# Ensure permissions.
RUN fix-permissions.sh $DOTNET_CLI_HOME
RUN chown -R $NB_USER:$NB_GID $HOME

USER $NB_USER

# Numpy multithreading uses MKL lib and for it to work properly on kubernetes
# this variable needs to be set. Else numpy thinks it has access to all cores on the node.
ENV MKL_THREADING_LAYER=GNU
ENV JUPYTER_ALLOW_INSECURE_WRITES=1

WORKDIR $HOME
CMD ["start.sh", "jupyter", "lab", "--ip", "0.0.0.0"]