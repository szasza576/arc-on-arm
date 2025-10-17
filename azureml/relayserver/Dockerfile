FROM mcr.microsoft.com/azureml/amlarc/docker/relayserver:1.1.88 as source

FROM alpine:3.21

CMD ["/bin/sh"]

ENV APP_UID=1654 ASPNETCORE_HTTP_PORTS=8080 DOTNET_RUNNING_IN_CONTAINER=true DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=true

RUN apk add --upgrade --no-cache \
        ca-certificates-bundle \
        libgcc \
        libssl3 \
        libstdc++ \
        zlib

RUN addgroup \
    --gid=$APP_UID \
    app \
    && adduser \
    --uid=$APP_UID \
    --ingroup=app \
    --disabled-password \
    app

ENV DOTNET_VERSION=8.0.20

RUN wget -O dotnet.tar.gz https://dotnetcli.azureedge.net/dotnet/Runtime/$DOTNET_VERSION/dotnet-runtime-$DOTNET_VERSION-linux-musl-arm64.tar.gz \
    && dotnet_sha512='3214b7ce77afbcb87e5baaaa4b88beed543dbc5f2cdfdd72b6471cb9dcd1bf3c56cc67dea9a2150d30dea0ef0c585c049db17243d9ec613ef928509eb9d64b4c' \
    && echo "$dotnet_sha512  dotnet.tar.gz" | sha512sum -c - \
    && mkdir -p /usr/share/dotnet \
    && tar -oxzf dotnet.tar.gz -C /usr/share/dotnet \
    && rm dotnet.tar.gz \
    && ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet

ENV ASPNET_VERSION=8.0.20

RUN wget -O aspnetcore.tar.gz https://dotnetcli.azureedge.net/dotnet/aspnetcore/Runtime/$ASPNET_VERSION/aspnetcore-runtime-$ASPNET_VERSION-linux-musl-arm64.tar.gz \
    && aspnetcore_sha512='f10e19379f76611f376ed19b701dcc2a3407cd83a57d806f9929295a90153fa28fc62740f8e5c34094a955e834a704bf401b0993f2528a0ee2f5d9cf876179bb' \
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
