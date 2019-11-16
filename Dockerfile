FROM jupyter/scipy-notebook:1386e2046833

USER root
RUN apt-get update && apt-get install -y htop neovim jq

# Install dotnet
RUN wget -q https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
RUN dpkg -i packages-microsoft-prod.deb
RUN apt-get update && \
    apt-get install -y htop neovim jq software-properties-common python3-software-properties && \
    add-apt-repository universe && \
    apt-get update && \
    apt-get install -y apt-transport-https dotnet-sdk-2.1 dotnet-sdk-3.0

USER jovyan

# Enable detection of running in a container
ENV DOTNET_RUNNING_IN_CONTAINER=true \
    # Enable correct mode for dotnet watch (only mode supported in a container)
    DOTNET_USE_POLLING_FILE_WATCHER=true \
    # Skip extraction of XML docs - generally not useful within an image/container - helps performance
    NUGET_XMLDOC_MODE=skip \
    # Opt out of telemetry until after we install jupyter when building the image, this prevents caching of machine id
    DOTNET_TRY_CLI_TELEMETRY_OPTOUT=true

# Trigger first run experience by running arbitrary cmd
RUN dotnet help

# Install Microsoft.DotNet.Interactive
RUN dotnet tool install --global dotnet-try

ENV PATH="${PATH}:${HOME}/.dotnet/tools"
RUN echo "$PATH"

# Install kernel specs
RUN dotnet try jupyter install

ENV MKL_THREADING_LAYER=GNU

CMD ["start.sh", "jupyter", "lab"]