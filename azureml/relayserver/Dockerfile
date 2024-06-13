FROM mcr.microsoft.com/azureml/amlarc/docker/relayserver:1.1.56 as source

FROM alpine:3.19

CMD ["/bin/sh"]

ENV ASPNETCORE_URLS=http://+:80 DOTNET_RUNNING_IN_CONTAINER=true DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=true

RUN apk add --upgrade --no-cache \
        ca-certificates \
        krb5-libs \
        libgcc \
        libintl \
        libssl3 \
        libstdc++ \
        zlib

ENV DOTNET_VERSION=7.0.18

RUN wget -O dotnet.tar.gz https://dotnetcli.azureedge.net/dotnet/Runtime/$DOTNET_VERSION/dotnet-runtime-$DOTNET_VERSION-linux-musl-arm64.tar.gz \
     && dotnet_sha512='0bb9e0bf5f29bd3c7e2e756f5504807f416d345b42ddf501fbef3150a485795d5db84724e1e08b14482a3822934a028bb5fd59defaf2e5eda97aac6fb84490bd' \
     && echo "$dotnet_sha512  dotnet.tar.gz" | sha512sum -c -     && mkdir -p /usr/share/dotnet     && tar -oxzf dotnet.tar.gz -C /usr/share/dotnet \
     && rm dotnet.tar.gz \
     && ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet
    
ENV ASPNET_VERSION=7.0.18

RUN wget -O aspnetcore.tar.gz https://dotnetcli.azureedge.net/dotnet/aspnetcore/Runtime/$ASPNET_VERSION/aspnetcore-runtime-$ASPNET_VERSION-linux-musl-arm64.tar.gz \
    && aspnetcore_sha512='0b34bb383e6bbc17489bdba0c006a866e56a532453a49b95e3d39c830924462f45c6b757ebb416a32e40180b852178c35ec1b64ad761f33b63a98ef60e01ceea' \
    && echo "$aspnetcore_sha512  aspnetcore.tar.gz" | sha512sum -c - \
    && tar -oxzf aspnetcore.tar.gz -C /usr/share/dotnet ./shared/Microsoft.AspNetCore.App \
    && rm aspnetcore.tar.gz

RUN apk update && apk upgrade

WORKDIR /app

COPY --from=source /app/* .

COPY --from=source /app/NOTICE.txt .
COPY --from=source /app/README.txt .
COPY --from=source /app/entrypoint.sh .

RUN chmod +x entrypoint.sh

ENTRYPOINT ["/bin/sh" "entrypoint.sh"]