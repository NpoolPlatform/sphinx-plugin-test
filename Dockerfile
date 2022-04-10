FROM jrei/systemd-ubuntu:20.04

USER root

#RUN sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list

RUN apt-get update -y
#RUN apt-get clean
#RUN apt-get update -y
RUN apt-get install vim git make curl wget -y

ARG ALL_PROXY
RUN apt-get install golang-go -y

RUN all_proxy=$ALL_PROXY curl -sL -o /tmp/go1.17.8.tar.gz https://github.com/golang/go/archive/refs/tags/go1.17.8.tar.gz
RUN mkdir -p /usr/local/go
RUN cd /usr/local/go; tar xvvf /tmp/go1.17.8.tar.gz
RUN mv /usr/local/go/go-go1.17.8/* /usr/local/go
RUN rm -rf /usr/local/go/go-go1.17.8
RUN cd /usr/local/go/src; ./all.bash
RUN cp /usr/local/go/bin/go /usr/bin/go

COPY ./bitcoin.conf /home
COPY ./install-tbtc.sh /home
COPY ./install-teth.sh /home
COPY ./install-bitcoin.sh /home
COPY ./install-ethereum-sphinx-plugin.sh /home
COPY ./install-usdterc20.sh /home
COPY ./install-filecoin-sphinx-plugin.sh /home

ENV GOBIN=/usr/bin
ENV GOROOT=/usr/local/go
ENV GOTOOLDIR=/usr/lib/go/pkg/tool/linux_amd64
