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

while getopts 'a:u:p:v:P:t:' OPT; do
  case $OPT in
    a) ALL_PROXY=$OPTARG          ;;
    u) RPC_USER=$OPTARG           ;;
    p) RPC_PASSWORD=$OPTARG       ;;
    v) BTC_VERSION=$OPTARG        ;;
    P) SPHINX_PROXY_ADDR=$OPTARG  ;;
    t) TRAEFIK_IP=$OPTARG         ;;
    *) usage $0                   ;;
  esac
done

LOG_FILE=/var/log/install-tbtc.log
echo > $LOG_FILE
info "RUN install tbtc" >> $LOG_FILE

function install_btc() {
  BTC_TAR=bitcoin-$BTC_VERSION-x86_64-linux-gnu.tar.gz
  info "download $BTC_TAR" >> $LOG_FILE
  all_proxy=$ALL_PROXY curl -o /home/$BTC_TAR https://bitcoin.org/bin/bitcoin-core-$BTC_VERSION/$BTC_TAR >> $LOG_FILE 2>&1
  cd /home
  rm -rf bitcoin-$BTC_VERSION
  tar xf $BTC_TAR
  bitcoin-cli -regtest stop
  sleep 5
  rm -rf /usr/local/bin/bitcoind /usr/local/bin/bitcoin-cli
  cp bitcoin-$BTC_VERSION/bin/bitcoind /usr/local/bin/
  cp bitcoin-$BTC_VERSION/bin/bitcoin-cli /usr/local/bin/
  bitcoind -regtest -addresstype=legacy -daemon -conf=/root/.bitcoin/bitcoin.conf -rpcuser=$RPC_USER -rpcpassword=$RPC_PASSWORD >> $LOG_FILE 2>&1
  sed -i 's/#rpcpassword=.*/rpcpassword='$RPC_PASSWORD'/g' /home/bitcoin.conf
  sed -i 's/#rpcuser=.*/rpcuser='$RPC_USER'/g' /home/bitcoin.conf
  echo "rpcwallet=my_wallet" >> /home/bitcoin.conf
  cp /home/bitcoin.conf /root/.bitcoin/
}

function install_sphinx_plugin() {
  mkdir -p /etc/SphinxPlugin /opt/sphinx-plugin
  rm -rf /home/sphinx-plugin
  info "clone sphinx-plugin" >> $LOG_FILE
  all_proxy=$ALL_PROXY git clone https://github.com/NpoolPlatform/sphinx-plugin.git /home/sphinx-plugin >> $LOG_FILE 2>&1
  cd /home/sphinx-plugin
  sed -i 's/sphinx_proxy_addr.*/sphinx_proxy_addr: "'$SPHINX_PROXY_ADDR'"/g' cmd/sphinx-plugin/SphinxPlugin.viper.yaml
  sed -i 's/ENV_COIN_API=/ENV_COIN_API=127.0.0.1:18443/g' systemd/sphinx-plugin.service
  sed -i '/ENV_COIN_API=/a\Environment="ENV_COIN_NET=test"' systemd/sphinx-plugin.service
  sed -i '/ENV_COIN_API=/a\Environment="ENV_COIN_TYPE=bitcoin"' systemd/sphinx-plugin.service
  sed -i '/ENV_COIN_API=/a\Environment="ENV_COIN_USER=$RPC_USER"' systemd/sphinx-plugin.service
  sed -i '/ENV_COIN_API=/a\Environment="ENV_COIN_PASS=$RPC_PASSWORD"' systemd/sphinx-plugin.service
  cp cmd/sphinx-plugin/SphinxPlugin.viper.yaml /etc/SphinxPlugin
  cp systemd/sphinx-plugin.service /etc/systemd/system
  export GOPROXY=https://goproxy.cn
  info "make verify" >> $LOG_FILE
  all_proxy=$ALL_PROXY make verify >> $LOG_FILE 2>&1
  rm -rf /opt/sphinx-plugin/sphinx-plugin
  cp output/linux/amd64/sphinx-plugin /opt/sphinx-plugin/
  echo "$TRAEFIK_IP sphinx.proxy.api.npool.top sphinx.proxy.api.xpool.top" >> /etc/hosts
}

function creat_btc_wallet() {
  bitcoin-cli -regtest createwallet my_wallet
  sleep 5
  bitcoin-cli -regtest -generate 101
  sleep 10
}

function run_crontab() {
  apt install cron
  echo "*/10 * * * * /usr/local/bin/bitcoin-cli -regtest -generate 1 > /var/log/cron.log 2>&1" > /var/spool/cron/crontabs/root
  chmod 600 /var/spool/cron/crontabs/root
  service cron start
  sleep 5
  touch /etc/default/locale
}

install_btc

systemctl stop sphinx-plugin
install_sphinx_plugin
systemctl daemon-reload
systemctl start sphinx-plugin
systemctl enable sphinx-plugin

creat_btc_wallet
run_crontab
