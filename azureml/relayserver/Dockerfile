FROM mcr.microsoft.com/azureml/amlarc/docker/relayserver:1.1.92 as source

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

ENV DOTNET_VERSION=8.0.22

RUN wget -O dotnet.tar.gz https://builds.dotnet.microsoft.com/dotnet/Runtime/$DOTNET_VERSION/dotnet-runtime-$DOTNET_VERSION-linux-musl-arm64.tar.gz \
    && dotnet_sha512='58c3b9070cf99ded0ce0f808cacf7b10e15dfd5f874cb09269921e76ff05390c0e621e5320c27012b98e04180d73c80d2063bbbd7d7bab17a099d0feed30ca1f' \
    && echo "$dotnet_sha512  dotnet.tar.gz" | sha512sum -c - \
    && mkdir -p /usr/share/dotnet \
    && tar -oxzf dotnet.tar.gz -C /usr/share/dotnet \
    && rm dotnet.tar.gz \
    && ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet

ENV ASPNET_VERSION=8.0.22

RUN wget -O aspnetcore.tar.gz https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/$ASPNET_VERSION/aspnetcore-runtime-$ASPNET_VERSION-linux-musl-arm64.tar.gz \
    && aspnetcore_sha512='527163f7eac703d08d8931739877c47799d0b27bd3e508b0931518b18aef9930eae18c697c7fde4b4319c65602ab7d9e6733ff86f3e51b1059f42f57f80c2688' \
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
