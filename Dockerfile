FROM ubuntu:22.04

LABEL org.opencontainers.image.authors="https://github.com/riedde"
LABEL org.opencontainers.image.authors="https://github.com/bwbohl"
LABEL org.opencontainers.image.authors="https://github.com/kepper"
LABEL org.opencontainers.image.source="https://github.com/music-encoding/docker-mei"
LABEL org.opencontainers.image.revision="v0.0.1"

ARG DEBIAN_FRONTEND=noninteractive
ARG JAVA_VERSION=17
ARG PRINCE_VERSION=15.1
ARG SAXON_VERSION=SaxonHE12-4
ARG TARGETARCH
ARG UBUNTU_VERSION=22.04
ARG XERCES_VERSION=25.1.0.1
ARG DEB_FILE=prince_${PRINCE_VERSION}-1_ubuntu${UBUNTU_VERSION}_${TARGETARCH}.deb

ENV TZ=Europe/Berlin
ENV ANT_VERSION=1.10.13

ENV ANT_HOME=/opt/apache-ant-${ANT_VERSION}
ENV PATH=${PATH}:${ANT_HOME}/bin
ENV NODE_ENV=production

USER root

# Configure the Eclipse Adoptium apt repository
RUN apt-get update && \
    apt-get install -y wget apt-transport-https && \
    mkdir -p /etc/apt/keyrings && \
    wget -O - https://packages.adoptium.net/artifactory/api/gpg/key/public | tee /etc/apt/keyrings/adoptium.asc && \
    echo "deb [signed-by=/etc/apt/keyrings/adoptium.asc] https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | tee /etc/apt/sources.list.d/adoptium.list
# install packages
RUN apt-get update && apt-get install -y --no-install-recommends apt-utils python3-pip temurin-${JAVA_VERSION}-jdk curl unzip git libc6 aptitude libaom-dev gdebi fonts-stix && \
    # install prince
    curl --proto '=https' --tlsv1.2 -O https://www.princexml.com/download/${DEB_FILE} && \
    gdebi --non-interactive ./${DEB_FILE} && \
    # install nodejs
    curl -fsSL https://deb.nodesource.com/setup_18.x -o nodesource_setup.sh && \
    bash nodesource_setup.sh && \
    apt install nodejs && \
    # link ca-certificates
    ln -sf /etc/ssl/certs/ca-certificates.crt /usr/lib/prince/etc/curl-ca-bundle.crt

# setup ant
ADD https://downloads.apache.org/ant/binaries/apache-ant-${ANT_VERSION}-bin.tar.gz /tmp/ant.tar.gz
RUN tar -xvf /tmp/ant.tar.gz -C /opt

# setup saxon
ADD https://github.com/Saxonica/Saxon-HE/releases/download/${SAXON_VERSION}/${SAXON_VERSION}J.zip /tmp/saxon.zip
RUN unzip /tmp/saxon.zip -d ${ANT_HOME}/lib

# setup xerces
ADD https://www.oxygenxml.com/maven/com/oxygenxml/oxygen-patched-xerces/${XERCES_VERSION}/oxygen-patched-xerces-${XERCES_VERSION}.jar ${ANT_HOME}/lib

# cleanup
RUN apt-get purge -y aptitude apt-utils gdebi curl unzip wget apt-transport-https && \
    apt-get autoremove -y && apt-get clean && \
    rm ${DEB_FILE} nodesource_setup.sh && \
    rm -rf /tmp/*

# setup node app for rendering MEI files to SVG using Verovio Toolkit
WORKDIR /opt/docker-mei
COPY ["index.js", "package.json", "package-lock.json*", "./"]
RUN npm install --production
