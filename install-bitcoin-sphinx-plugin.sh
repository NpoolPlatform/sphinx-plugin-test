#!/bin/bash
export all_proxy=$ALL_PROXY

function info() {
  echo "  <I> -> $1 ~"
}

function usage() {
  echo "Usage:"
  echo "  $1 -[a:u:p:v:P:t:H:]"
  echo "    -a            All proxy"
  echo "    -u            Rpc user"
  echo "    -p            Rpc password"
  echo "    -v            BTC version"
  echo "    -P            Sphinx proxy addr"
  echo "    -t            Traefik ip"
  echo "    -H            Show this help"
  [ "xtrue" == "x$2" ] && exit 0
  return 0
}

while getopts 'a:u:p:v:P:t:N:I:' OPT; do
  case $OPT in
    a) ALL_PROXY=$OPTARG          ;;
    u) RPC_USER=$OPTARG           ;;
    p) RPC_PASSWORD=$OPTARG       ;;
    v) BTC_VERSION=$OPTARG        ;;
    P) SPHINX_PROXY_ADDR=$OPTARG  ;;
    t) TRAEFIK_IP=$OPTARG         ;;
    N) COIN_NET=$OPTARG           ;;
    I) HOST_IP=$OPTARG            ;;
    *) usage $0                   ;;
  esac
done

LOG_FILE=/var/log/install-bitcoin.log
echo > $LOG_FILE
info "RUN install bitcoin" >> $LOG_FILE


function install_sphinx_plugin() {
  mkdir -p /etc/SphinxPlugin /opt/sphinx-plugin
  rm -rf /home/sphinx-plugin
  info "clone sphinx-plugin" >> $LOG_FILE
  all_proxy=$ALL_PROXY git clone https://github.com/NpoolPlatform/sphinx-plugin.git /home/sphinx-plugin >> $LOG_FILE 2>&1
  cd /home/sphinx-plugin
  export GOPROXY=https://goproxy.cn
  info "make verify" >> $LOG_FILE
  all_proxy=$ALL_PROXY make verify >> $LOG_FILE 2>&1
  rm -rf /opt/sphinx-plugin/sphinx-plugin
  cp output/linux/amd64/sphinx-plugin /opt/sphinx-plugin/
  cp cmd/sphinx-plugin/SphinxPlugin.viper.yaml /etc/SphinxPlugin
  cp systemd/sphinx-plugin.service /etc/systemd/system
  sed -i 's/sphinx_proxy_addr.*/sphinx_proxy_addr: "'$SPHINX_PROXY_ADDR'"/g' /etc/SphinxPlugin/SphinxPlugin.viper.yaml
  sed -i '/ENV_COIN_API=/a\Environment="ENV_COIN_NET='$COIN_NET'"' /etc/systemd/system/sphinx-plugin.service
  sed -i '/ENV_COIN_API=/a\Environment="ENV_COIN_USER='$RPC_USER'"' /etc/systemd/system/sphinx-plugin.service
  sed -i '/ENV_COIN_API=/a\Environment="ENV_COIN_PASS='$RPC_PASSWORD'"' /etc/systemd/system/sphinx-plugin.service
  sed -i '/ENV_COIN_API=/a\Environment="ENV_COIN_TYPE=bitcoin"' /etc/systemd/system/sphinx-plugin.service
  if [ "$COIN_NET" == "main" ]; then
    sed -i 's/ENV_COIN_API=/ENV_COIN_API='$HOST_IP':8332/g' /etc/systemd/system/sphinx-plugin.service
  else
    sed -i 's/ENV_COIN_API=/ENV_COIN_API='$HOST_IP':18443/g' /etc/systemd/system/sphinx-plugin.service
    echo "$TRAEFIK_IP sphinx.proxy.api.npool.top sphinx.proxy.api.xpool.top" >> /etc/hosts
  fi
}

install_sphinx_plugin
systemctl daemon-reload
systemctl start sphinx-plugin
systemctl enable sphinx-plugin
