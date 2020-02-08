FROM jupyter/datascience-notebook:7a0c7325e470

USER root
RUN apt-get update && apt-get install -y htop neovim jq graphviz libopenblas-dev

USER jovyan

# Lock jupyter client version because a bug for windows has been introduced in later versions.
# Restrict plotly version because we need it to be in sync with cufflinks.
# Degrade jupyterhub 1.0.0 -> 0.9.6 because https://github.com/jupyterhub/zero-to-jupyterhub-k8s stable depends on it.
RUN conda install -y jupyter_client=5.3.1 jupyterhub=0.9.6 \
    fastparquet pyarrow python-snappy pandas numpy=1 \
    cvxopt cvxpy lxml line_profiler cookiecutter dash=1 plotly=4 gunicorn \
    pandas-profiling requests_ntlm dask=2.9.0 distributed=2.9.0

RUN conda install -c conda-forge pymc3=3 theano mkl-service seaborn \
    tqdm aiofiles aiohttp html5lib spacy python-graphviz dask-kubernetes=0.10.0 s3fs
RUN conda install -c r rpy2
RUN conda install -c pytorch pytorch-cpu=1 torchvision-cpu

# Install cufflinks and jupyter plotly extension, requires jupyterlab=1.2 and ipywidgets=7.5
RUN pip install cufflinks==0.17.0 chart_studio==1.0.0 impyute fancyimpute pydot

# Jupyter lab extensions
# Avoid "JavaScript heap out of memory" errors during extension installation
RUN export NODE_OPTIONS=--max-old-space-size=4096
# Jupyter widgets extension
RUN jupyter labextension install @jupyter-widgets/jupyterlab-manager@1.1 --no-build

# FigureWidget support
# and jupyterlab renderer support
RUN jupyter labextension install plotlywidget@1.4.0 --no-build
RUN jupyter labextension install jupyterlab-plotly@1.4.0 --no-build

RUN jupyter labextension install jupyterlab_vim --no-build

# Build extensions (must be done to activate extensions since --no-build is used above)
RUN jupyter lab build

# Unset NODE_OPTIONS environment variable
RUN unset NODE_OPTIONS

RUN pip install jupyter-server-proxy && jupyter serverextension enable --sys-prefix jupyter_server_proxy

# Numpy multithreading uses MKL lib and for it to work properly on kubernetes
# this variable needs to be set. Else numpy thinks it has access to all cores on the node.
ENV MKL_THREADING_LAYER=GNU

USER root

# Install dotnet kernels
# Install .NET CLI dependencies
RUN apt-get install -y --no-install-recommends \
        libc6 \
        libgcc1 \
        libgssapi-krb5-2 \
        libicu60 \
        libssl1.1 \
        libstdc++6 \
        zlib1g 

RUN rm -rf /var/lib/apt/lists/*

USER jovyan

# dotnet sdk, using pre-built binaries
RUN wget -q https://download.visualstudio.microsoft.com/download/pr/c4b503d6-2f41-4908-b634-270a0a1dcfca/c5a20e42868a48a2cd1ae27cf038044c/dotnet-sdk-3.1.101-linux-x64.tar.gz
RUN mkdir -p /opt/dotnet && tar zxf dotnet-sdk-3.1.101-linux-x64.tar.gz -C /opt/dotnet

# Enable detection of running in a container
ENV DOTNET_RUNNING_IN_CONTAINER=true \
    # Enable correct mode for dotnet watch (only mode supported in a container)
    DOTNET_USE_POLLING_FILE_WATCHER=true \
    # Skip extraction of XML docs - generally not useful within an image/container - helps performance
    NUGET_XMLDOC_MODE=skip \
    # Opt out of telemetry until after we install jupyter when building the image, this prevents caching of machine id
    DOTNET_TRY_CLI_TELEMETRY_OPTOUT=true

# Add to bashrc
ENV DOTNET_ROOT=/opt/dotnet
ENV PATH=$PATH:$DOTNET_ROOT
ENV PATH=$PATH:$DOTNET_ROOT/tools

# Trigger first run experience by running arbitrary cmd
RUN dotnet help

# Install dotnet interactive
RUN dotnet tool install --tool-path $DOTNET_ROOT/tools --add-source "https://dotnet.myget.org/F/dotnet-try/api/v3/index.json" Microsoft.dotnet-interactive

# Install kernel specs
RUN dotnet interactive jupyter install

CMD ["start.sh", "jupyter", "lab"]
