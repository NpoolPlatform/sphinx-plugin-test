#!/bin/bash

function info() {
  echo "  <I> -> $1 ~"
}

function usage() {
  echo "Usage:"
  echo "  $1 -[P:t:H:]"
  echo "    -P            Sphinx proxy addr"
  echo "    -t            Traefik ip"
  echo "    -H            Show this help"
  [ "xtrue" == "x$2" ] && exit 0
  return 0
}

while getopts 'P:t:' OPT; do
  case $OPT in
    P) SPHINX_PROXY_ADDR=$OPTARG  ;;
    t) TRAEFIK_IP=$OPTARG         ;;
    *) usage $0                   ;;
  esac
done

LOG_FILE=/var/log/install-teth.log
echo > $LOG_FILE
info "RUN install eth" >> $LOG_FILE

function install_eth() {
  apt install software-properties-common -y
  apt-get update
  add-apt-repository -y ppa:ethereum/ethereum
  apt-get update
  apt-get install ethereum -y
  cd /home
  nohup geth --http --datadir ./node0 --dev --dev.period 1 --mine --miner.threads 2 --http.api 'eth,net,web3,miner,personal'> geth.log 2>&1 &
}

function install_sphinx_plugin() {
  mkdir -p /etc/SphinxPlugin /opt/sphinx-plugin
  rm -rf /home/sphinx-plugin
  info "clone sphinx-plugin" >> $LOG_FILE
  git clone https://github.com/NpoolPlatform/sphinx-plugin.git /home/sphinx-plugin >> $LOG_FILE 2>&1
  cd /home/sphinx-plugin
  export GOPROXY=https://goproxy.cn
  info "make verify" >> $LOG_FILE
  make verify >> $LOG_FILE 2>&1
  rm -rf /opt/sphinx-plugin/sphinx-plugin
  cp output/linux/amd64/sphinx-plugin /opt/sphinx-plugin/
  ContractID=`output/linux/amd64/sphinx-plugin usdt -addr 127.0.0.1 -port 8545 | grep "Contract:" | awk '{print $4}'`
  sed -i 's/contractID.*/contractID: "'$ContractID'"/g' cmd/sphinx-plugin/SphinxPlugin.viper.yaml
  sed -i 's/sphinx_proxy_addr.*/sphinx_proxy_addr: "'$SPHINX_PROXY_ADDR'"/g' cmd/sphinx-plugin/SphinxPlugin.viper.yaml
  sed -i '/ENV_COIN_API=/a\Environment="ENV_COIN_NET=test"' systemd/sphinx-plugin.service
  sed -i '/ENV_COIN_API=/a\Environment="ENV_COIN_TYPE=ethereum,usdt"' systemd/sphinx-plugin.service
  cp cmd/sphinx-plugin/SphinxPlugin.viper.yaml /etc/SphinxPlugin
  cp systemd/sphinx-plugin.service /etc/systemd/system
  echo "$TRAEFIK_IP sphinx.proxy.api.npool.top sphinx.proxy.api.xpool.top" >> /etc/hosts
}

install_eth

systemctl stop sphinx-plugin
install_sphinx_plugin
systemctl daemon-reload
systemctl start sphinx-plugin
systemctl enable sphinx-plugin
