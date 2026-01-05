FROM mcr.microsoft.com/azureml/amlarc/docker/relayserver:1.1.91 as source

FROM alpine:3.22.2

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

ENV DOTNET_VERSION=8.0.21

RUN wget -O dotnet.tar.gz https://builds.dotnet.microsoft.com/dotnet/Runtime/$DOTNET_VERSION/dotnet-runtime-$DOTNET_VERSION-linux-musl-arm64.tar.gz \
    && dotnet_sha512='4fb31259fa8bcc250989c0e906d52dfa2ff5a25f2addd38678d788ed297dba0fe5a9477f9b003b06aaaf05aa79d6684ce5d7b5f49be218e472a2cc60f812fa7f' \
    && echo "$dotnet_sha512  dotnet.tar.gz" | sha512sum -c - \
    && mkdir -p /usr/share/dotnet \
    && tar -oxzf dotnet.tar.gz -C /usr/share/dotnet \
    && rm dotnet.tar.gz \
    && ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet

ENV ASPNET_VERSION=8.0.21

RUN wget -O aspnetcore.tar.gz https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/$ASPNET_VERSION/aspnetcore-runtime-$ASPNET_VERSION-linux-musl-arm64.tar.gz \
    && aspnetcore_sha512='7629c7a8316970a63546b88831dda77650f2a307615df42d735c75e299b935ec1f529f29315e444d16fa498339e3aaf7b961a918ac9efe66debc8ab79e1fb746' \
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
