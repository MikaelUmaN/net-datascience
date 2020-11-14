FROM mikaeluman/datascience:latest

ARG NB_USER=jovyan
ARG NB_UID=1000
ENV USER ${NB_USER}
ENV NB_UID ${NB_UID}
ENV HOME /home/${NB_USER}

WORKDIR ${HOME}

USER root

RUN wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
RUN dpkg -i packages-microsoft-prod.deb

# Install .NET CLI dependencies
RUN apt-get update; \
  apt-get install -y apt-transport-https && \
  apt-get update && \
  apt-get install -y dotnet-sdk-5.0

# Still needed for e.g. dotnet interactive...
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

RUN chown -R ${NB_UID} ${HOME}

RUN usermod -aG sudo ${USER}
RUN echo "${USER}  ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/${USER}

USER ${USER}

# Install lastest build from master branch of Microsoft.DotNet.Interactive from myget
RUN dotnet tool install -g Microsoft.dotnet-interactive --version 1.0.150201 --add-source "https://dotnet.myget.org/F/dotnet-try/api/v3/index.json"

RUN dotnet tool install -g fake-cli
RUN dotnet tool install -g paket

ENV PATH="${PATH}:${HOME}/.dotnet/tools"
RUN echo "$PATH"

# Install kernel specs
RUN dotnet interactive jupyter install

# Make F# projects default for dotnet new cli
ENV DOTNET_NEW_PREFERRED_LANG=F#

RUN npm install -g yarn

CMD ["start.sh", "jupyter", "lab"]
