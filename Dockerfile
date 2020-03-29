FROM mikaeluman/datascience:2020-03

ARG NB_USER=jovyan
ARG NB_UID=1000
ENV USER ${NB_USER}
ENV NB_UID ${NB_UID}
ENV HOME /home/${NB_USER}

WORKDIR ${HOME}

USER root

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

# Install .NET Core SDK

# When updating the SDK version, the sha512 value a few lines down must also be updated.
ENV DOTNET_SDK_VERSION 5.0.100-preview.1.20155.7

RUN curl -SL --output dotnet.tar.gz https://download.visualstudio.microsoft.com/download/pr/c3d1886b-6846-4328-9692-a0adcdf30959/f0bd5e15b1825fc8f5b0a8166008e08a/dotnet-sdk-$DOTNET_SDK_VERSION-linux-x64.tar.gz \
    && dotnet_sha512='e768641ef12604400edf4ba25bd7ea7a2e64c69fa447661b478ceff89f3c77c07ec69f3aa05b966400e88caae4f548a7bfc5a0747f511b5a10e88dd616f73b21' \
    && echo "$dotnet_sha512 dotnet.tar.gz" | sha512sum -c - \
    && mkdir -p /usr/share/dotnet \
    && tar -zxf dotnet.tar.gz -C /usr/share/dotnet \
    && rm dotnet.tar.gz \
    && ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet

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
#RUN dotnet tool install -g Microsoft.dotnet-interactive --version 1.0.117301 --add-source "https://dotnet.myget.org/F/dotnet-try/api/v3/index.json"

ENV PATH="${PATH}:${HOME}/.dotnet/tools"
RUN echo "$PATH"

# Install kernel specs
#RUN dotnet interactive jupyter install

CMD ["start.sh", "jupyter", "lab"]
