#!/bin/bash
export all_proxy=$ALL_PROXY

function info() {
  echo "  <I> -> $1 ~"
}

function usage() {
  echo "Usage:"
  echo "  $1 -[a:P:t:H:]"
  echo "    -a            All proxy"
  echo "    -P            Sphinx proxy addr"
  echo "    -t            Traefik ip"
  echo "    -H            Show this help"
  [ "xtrue" == "x$2" ] && exit 0
  return 0
}

while getopts 'a:P:t:' OPT; do
  case $OPT in
    a) ALL_PROXY=$OPTARG          ;;
    P) SPHINX_PROXY_ADDR=$OPTARG  ;;
    t) TRAEFIK_IP=$OPTARG         ;;
    *) usage $0                   ;;
  esac
done

LOG_FILE=/var/log/install-teth.log
echo > $LOG_FILE
info "RUN install teth" >> $LOG_FILE

function install_eth() {
  apt install software-properties-common -y
  apt-get update
  add-apt-repository -y ppa:ethereum/ethereum
  apt-get update
  info "install ethereum" >> $LOG_FILE
  apt-get install ethereum -y >> $LOG_FILE 2>&1
  sleep 10
  cd /home
  info "run geth" >> $LOG_FILE
  nohup geth --http --dev --dev.period 1 --mine --miner.threads 2 --http.api 'eth,net,web3,miner,personal'> /root/.ethereum/geth.log 2>&1 &
}

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
  rm -rf /usr/local/bin/sphinx-plugin
  cp output/linux/amd64/sphinx-plugin /opt/sphinx-plugin/
  cp output/linux/amd64/sphinx-plugin /usr/local/bin/
  sed -i 's/ENV_COIN_API=/ENV_COIN_API=127.0.0.1:8545/g' systemd/sphinx-plugin.service
  sed -i '/ENV_COIN_API=/a\Environment="ENV_COIN_NET=test"' systemd/sphinx-plugin.service
  sed -i '/ENV_COIN_API=/a\Environment="ENV_COIN_TYPE=ethereum,usdterc20"' systemd/sphinx-plugin.service
  sed -i 's/sphinx_proxy_addr.*/sphinx_proxy_addr: "'$SPHINX_PROXY_ADDR'"/g' cmd/sphinx-plugin/SphinxPlugin.viper.yaml
  cp cmd/sphinx-plugin/SphinxPlugin.viper.yaml /etc/SphinxPlugin/
  cp systemd/sphinx-plugin.service /etc/systemd/system/
  echo "$TRAEFIK_IP sphinx.proxy.api.npool.top sphinx.proxy.api.xpool.top" >> /etc/hosts
}

function install_usdt() {
  ContractID=`sphinx-plugin usdterc20 -addr 127.0.0.1 -port 8545 | grep "Contract:" | awk '{print $4}'`
  info "ContractID = $ContractID" >> $LOG_FILE
  echo "$ContractID" > /root/.ethereum/contractid
  sed -i 's/contract_id.*/contract_id: "'$ContractID'"/g' /etc/SphinxPlugin/SphinxPlugin.viper.yaml
}

install_eth

systemctl stop sphinx-plugin
install_sphinx_plugin
systemctl daemon-reload
systemctl start sphinx-plugin
systemctl enable sphinx-plugin

ContractID=`cat /root/.ethereum/contractid`
if [ -n $ContractID ]; then
  sed -i 's/contract_id.*/contract_id: "'$ContractID'"/g' /etc/SphinxPlugin/SphinxPlugin.viper.yaml
else
  install_usdt
fi

systemctl restart sphinx-plugin
