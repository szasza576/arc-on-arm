FROM mcr.microsoft.com/azureml/inference-base-2004:20240515.v1 as source

FROM --platform=linux/arm64 ubuntu:20.04 as inference-base

ARG IMAGE_INFORMATION=inference-base-2004:20240515.v2
USER root:root
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV DEBIAN_FRONTEND=noninteractive
ARG LIBLTTNG=liblttng-ust0
ARG LIBSSL=libssl1.1
ARG LIBJSON=libjson-c4

RUN apt-get update && \
    apt-get install -y software-properties-common && \
    add-apt-repository -y ppa:adiscon/v8-stable && \
    apt-get purge -y software-properties-common && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        perl \
        libssh-4 \
        tar \
        procps \
        libprocps8 \
        libgnutls30 \
        libk5crypto3 \
        libkrb5-3 \
        libkrb5support0 \
        binutils-multiarch \
        binutils \
        libpam-modules \
        libpam-runtime \
        libpam0g \
        libgssapi-krb5-2 \
        nginx-light \
        rsyslog \
        runit \
        wget \
        libcurl4 \
        $LIBLTTNG \
        libunwind8 \
        libxml++2.6-2v5 \
        psmisc \
        build-essential \
        unzip \
        libudev1 \
        $LIBSSL \
        login \
        passwd \
        libtinfo6 \
        libncurses6 \
        ncurses-bin \
        ncurses-base \
        libncursesw6 \
        libcap2 \
        $LIBJSON \
        libelf1 \
        libc6 \
        libc-dev-bin \
        libc6-dev \
        libc-bin \
        expat \
        libexpat1 \
        bash \
        libnghttp2-14 \
        util-linux \
        libuuid1 \
        libblkid1 \
        fdisk \
        libfdisk1 \
        mount \
        libsmartcols1 \
        libmount1 \
        systemd \
        libgl1 \
        libglib2.0-0 && \
    apt-get autoremove -y && \
    apt-get clean -y && \
    rm -rf /usr/share/man/* && \
    rm -rf /var/lib/apt/lists/*
COPY --from=source /LICENSE.txt /
COPY --from=source /NOTICE.txt /
COPY --from=source /var/azureml-logger /var/azureml-logger
COPY --from=source /var/azureml-util /var/azureml-util
COPY --from=source /var/runit /var/runit
COPY --from=source /etc/rsyslog.conf /etc/rsyslog.conf
COPY --from=source /etc/nginx/sites-available/app /etc/nginx/sites-available/app

RUN ln -s /etc/nginx/sites-available/app /etc/nginx/sites-enabled/app && \
    rm -f /etc/nginx/sites-enabled/default
ENV SVDIR=/var/runit
ENV WORKER_TIMEOUT=300
ENV AZUREML_INFERENCE_SERVER_HTTP_ENABLED=True
EXPOSE 5001

# COPY grant_ownership.sh /tmp/
# Note: This file was deleted in the source image hence it cannot be directly copied.
# Instead, it can be extracted from a lower layer and pasted here as a print to file as a replacement of the original step.

COPY <<"EOT" /tmp/grant_ownership.sh
#!/bin/sh

# we transfer ownership of certain files and directories to dockeruser
# for each command below, the comment above it the error that occurs if we don't transfer ownership

# runsv iot-server: fatal: unable to open supervise/lock: file does not exist
# runsv gunicorn: fatal: unable to open supervise/lock: file does not exist
# runsv rsyslog: fatal: unable to open supervise/lock: file does not exist
# runsv nginx: fatal: unable to open supervise/lock: file does not exist
chown -R dockeruser /var/runit

# nginx: [alert] could not open error log file: open() "/var/log/nginx/error.log" failed (13: Permission denied)
chown -R dockeruser /var/log

# nginx: [emerg] mkdir() "/var/lib/nginx/body" failed (13: Permission denied)
chown -R dockeruser /var/lib/nginx

# nginx: [emerg] open() "/run/nginx.pid" failed (13: Permission denied)
# see nginx.conf: nginx writes its pid to /var/run/nginx.pid
chown -R dockeruser /run

# dockeruser needs execute permission for start_logger.sh
chmod +x /var/azureml-logger/start_logger.sh

# NotWritableError: The current user does not have write permissions to a required path.
# path: /opt/miniconda/pkgs/urls.txt
mkdir -p '/opt/miniconda/'
chown -R dockeruser /opt/miniconda/

# Permission error during Model.package() with userManagedDependencies = true
# mkdir: cannot create directory ‘/var/azureml-app’: Permission denied
# The command '/bin/sh -c mkdir -p '/var/azureml-app' && /var/azureml-util/download_asset.sh 'https://adbaws2171295715.blob.core.windows.net/azureml/LocalUpload/c37eefc7/tmpgrflit_r.py?sv=2019-02-02&sr=b&sig=JPoMtgp9tcsp7YiB209dR5zDrVduRZ2lKDlSzjRCGB4%3D&st=2021-03-06T01%3A10%3A50Z&se=2021-03-06T09%3A20%3A50Z&sp=r' '/var/azureml-app/tmpgrflit_r.py' && /var/azureml-util/download_asset.sh 'https://adbaws2171295715.blob.core.windows.net/azureml/LocalUpload/456c032d/score.py?sv=2019-02-02&sr=b&sig=LgMt879pdVmV33FjFb8IGjxO7NRZKaVtzj06HjiYEhw%3D&st=2021-03-06T01%3A10%3A51Z&se=2021-03-06T09%3A20%3A51Z&sp=r' '/var/azureml-app/score.py'' returned a non-zero code: 1
# 2021/03/06 01:22:30 Container failed during run: acb_step_1. No retries remaining.
# failed to run step ID: acb_step_1: exit status 1
# Explanation: EMS tries to create this directory as non-root and that fails.
# We create it ahead early to avoid the failure.
mkdir -p '/var/azureml-app'
chown -R dockeruser /var/azureml-app
EOT

# RUN bash generate_notice.sh && rm generate_notice.sh
# Note: this was copied from the original image hence the step is skipped

RUN echo $IMAGE_INFORMATION > /IMAGE_INFORMATION
RUN useradd --create-home dockeruser
RUN bash /tmp/grant_ownership.sh && rm -f /tmp/grant_ownership.sh
USER dockeruser
ENV PATH=/opt/miniconda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
RUN wget -qO /tmp/miniconda.sh https://repo.continuum.io/miniconda/Miniconda3-py39_23.3.1-0-Linux-aarch64.sh && \
    bash /tmp/miniconda.sh -bf -p /opt/miniconda && \
    conda install \
        requests=2.31.0 \
        cryptography=42.0.4 \
        urllib3=1.26.18 \
        idna=3.7 \
        tqdm=4.66.4 \
        pip==23.3 \
        -c conda-forge -y && \
    conda clean -ay && \
    rm -rf /opt/miniconda/pkgs && \
    rm -f /tmp/miniconda.sh && \
    find /opt/miniconda -type d -name __pycache__ | xargs rm -rf
ENV AZUREML_CONDA_ENVIRONMENT_PATH=/opt/miniconda/envs/amlenv
ENV PATH=/opt/miniconda/envs/amlenv/bin:/opt/miniconda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

FROM inference-base

WORKDIR /
ENV AZUREML_CONDA_ENVIRONMENT_PATH=/azureml-envs/minimal
ENV AZUREML_CONDA_DEFAULT_ENVIRONMENT=$AZUREML_CONDA_ENVIRONMENT_PATH

# Prepend path to AzureML conda environment
ENV PATH $AZUREML_CONDA_ENVIRONMENT_PATH/bin:$PATH

ENV LD_LIBRARY_PATH /usr/lib/aarch64-linux-gnu:$AZUREML_CONDA_ENVIRONMENT_PATH/lib:$LD_LIBRARY_PATH

# Create conda environment
USER root
COPY conda_dependencies.yaml .
RUN conda env create -p $AZUREML_CONDA_ENVIRONMENT_PATH -f conda_dependencies.yaml && \
    rm conda_dependencies.yaml && \
    conda run -p $AZUREML_CONDA_ENVIRONMENT_PATH pip cache purge && \
    conda clean -a -y
USER dockeruser

CMD [ "runsvdir", "/var/runit" ]