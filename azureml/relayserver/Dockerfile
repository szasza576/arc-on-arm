FROM mcr.microsoft.com/azureml/amlarc/docker/relayserver:1.1.53 as source

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

ENV DOTNET_VERSION=7.0.17

RUN wget -O dotnet.tar.gz https://dotnetcli.azureedge.net/dotnet/Runtime/$DOTNET_VERSION/dotnet-runtime-$DOTNET_VERSION-linux-musl-arm64.tar.gz \
     && dotnet_sha512='e2cafec76472a62f3d48c03bd9e87ca355b73b4dc13bacd858f0175e6eb2da999419e66abcbed35775d37a8bb8ccbf8ddc87075605312d8833ecf77649f286aa' \
     && echo "$dotnet_sha512  dotnet.tar.gz" | sha512sum -c -     && mkdir -p /usr/share/dotnet     && tar -oxzf dotnet.tar.gz -C /usr/share/dotnet \
     && rm dotnet.tar.gz \
     && ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet
    
ENV ASPNET_VERSION=7.0.17

RUN wget -O aspnetcore.tar.gz https://dotnetcli.azureedge.net/dotnet/aspnetcore/Runtime/$ASPNET_VERSION/aspnetcore-runtime-$ASPNET_VERSION-linux-musl-arm64.tar.gz \
    && aspnetcore_sha512='07097cdd1cead0d87825895e0371477d5b9683611df10f66cda6816b82d0d293aba73966951d30aa364728035c86ee6950a559eaf7cc2661205d5140d9fdb6d0' \
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