FROM mikaeluman/datascience:latest

ARG NB_USER=jovyan
ARG NB_UID=1000
ENV USER ${NB_USER}
ENV NB_UID ${NB_UID}
ENV HOME /home/${NB_USER}

WORKDIR ${HOME}

USER root

# Install .NET CLI dependencies
RUN apt-get update && apt-get upgrade -y
RUN apt-get install -y --no-install-recommends \
        libc6 \
        libgcc1 \
        libgssapi-krb5-2 \
        libicu60 \
        libssl1.1 \
        libstdc++6 \
        zlib1g

RUN rm -rf /var/lib/apt/lists/*

# Install .NET Core SDK

# When updating the SDK version, the sha512 value a few lines down must also be updated.
ENV DOTNET_SDK_VERSION 3.1.300

RUN curl -SL --output dotnet.tar.gz https://download.visualstudio.microsoft.com/download/pr/0c795076-b679-457e-8267-f9dd20a8ca28/02446ea777b6f5a5478cd3244d8ed65b/dotnet-sdk-$DOTNET_SDK_VERSION-linux-x64.tar.gz \
    && dotnet_sha512='1c3844ea5f8847d92372dae67529ebb08f09999cac0aa10ace571c63a9bfb615adbf8b9d5cebb2f960b0a81f6a5fba7d80edb69b195b77c2c7cca174cbc2fd0b' \
    && echo "$dotnet_sha512 dotnet.tar.gz" | sha512sum -c - \
    && mkdir -p /usr/share/dotnet \
    && tar -zxf dotnet.tar.gz -C /usr/share/dotnet \
    && rm dotnet.tar.gz \
    && ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet

# Install preview of next SDK version.
# When updating the SDK version, the sha512 value a few lines down must also be updated.
ENV DOTNET_SDK_VERSION_PREV 5.0.100-preview.5.20279.10

RUN curl -SL --output dotnet5.tar.gz https://download.visualstudio.microsoft.com/download/pr/7cf9fa3e-af03-4181-baab-e04ed4b05268/fd44776a5169d6b126ee11d6140691be/dotnet-sdk-$DOTNET_SDK_VERSION_PREV-linux-x64.tar.gz \
    && dotnet_sha512='0ee982dd7b6015d05c04a33ffba77fa9f61863578c5fd7c4b3847043da2fd17c36b2f8535af53f46dee66e9e59a52f5e7c995af7f9a69fbd3abbc524aca5931b' \
    && echo "$dotnet_sha512 dotnet5.tar.gz" | sha512sum -c - \
    && mkdir -p /usr/share/dotnet5 \
    && tar -zxf dotnet5.tar.gz -C /usr/share/dotnet5 \
    && rm dotnet5.tar.gz \
    && ln -s /usr/share/dotnet5/dotnet /usr/bin/dotnet5

# Enable detection of running in a container
ENV DOTNET_RUNNING_IN_CONTAINER=true \
    # Enable correct mode for dotnet watch (only mode supported in a container)
    DOTNET_USE_POLLING_FILE_WATCHER=true \
    # Skip extraction of XML docs - generally not useful within an image/container - helps performance
    NUGET_XMLDOC_MODE=skip \
    # Opt out of telemetry until after we install jupyter when building the image, this prevents caching of machine id
    DOTNET_TRY_CLI_TELEMETRY_OPTOUT=true

RUN chown -R ${NB_UID} ${HOME}
USER ${USER}

# Install lastest build from master branch of Microsoft.DotNet.Interactive from myget
RUN dotnet tool install -g Microsoft.dotnet-interactive --version 1.0.131806 --add-source "https://dotnet.myget.org/F/dotnet-try/api/v3/index.json"
RUN dotnet tool install -g fake-cli
RUN dotnet tool install -g Paket

ENV PATH="${PATH}:${HOME}/.dotnet/tools"
RUN echo "$PATH"

# Install kernel specs
RUN dotnet interactive jupyter install

# Make F# projects default for dotnet new cli
ENV DOTNET_NEW_PREFERRED_LANG=F#

RUN npm install -g yarn

CMD ["start.sh", "jupyter", "lab"]
