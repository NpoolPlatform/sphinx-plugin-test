#!/bin/bash

function usage() {
  echo "Usage:"
  echo "  $1 -[u:p:v:P:H:]"
  echo "    -u            Rpc user"
  echo "    -p            Rpc password"
  echo "    -v            BTC version"
  echo "    -P            Sphinx proxy addr"
  echo "    -H            Show this help"
  [ "xtrue" == "x$2" ] && exit 0
  return 0
}

while getopts 'u:p:v:P:' OPT; do
  case $OPT in
    u) RPC_USER=$OPTARG           ;;
    p) RPC_PASSWORD=$OPTARG       ;;
    v) BTC_VERSION=$OPTARG        ;;
    P) SPHINX_PROXY_ADDR=$OPTARG  ;;
    *) usage $0                   ;;
  esac
done

function install_btc() {
  BTC_TAR=bitcoin-$BTC_VERSION-x86_64-linux-gnu.tar.gz
  curl -o /home/$BTC_TAR https://bitcoin.org/bin/bitcoin-core-$BTC_VERSION/$BTC_TAR
  cd /home
  rm -rf bitcoin-$BTC_VERSION
  tar xf $BTC_TAR
  kill -9 `pgrep -f 'bitcoind'`
  sleep 5
  rm -rf /usr/local/bin/bitcoind /usr/local/bin/bitcoin-cli
  cp bitcoin-$BTC_VERSION/bin/bitcoind /usr/local/bin/
  cp bitcoin-$BTC_VERSION/bin/bitcoin-cli /usr/local/bin/
  bitcoind -regtest -addresstype=legacy -daemon -conf=~/.bitcoin/bitcoin.conf -rpcuser=$RPC_USER -rpcpassword=$RPC_PASSWORD
  sed -i 's/#rpcpassword=.*/rpcpassword='$RPC_PASSWORD'/g' /home/bitcoin.conf
  sed -i 's/#rpcuser=alice/rpcuser='$RPC_USER'/g' /home/bitcoin.conf
  cp /home/bitcoin.conf ~/.bitcoin
}

function install_sphinx_plugin() {
  mkdir -p /etc/SphinxPlugin /opt/sphinx-plugin
  rm -rf /home/sphinx-plugin
  git clone https://github.com/NpoolPlatform/sphinx-plugin.git /home/sphinx-plugin
  cd /home/sphinx-plugin
  sed -i 's/sphinx_proxy_addr.*/sphinx_proxy_addr: "'$SPHINX_PROXY_ADDR'"/g' cmd/sphinx-plugin/SphinxPlugin.viper.yaml
  sed -i 's/ENV_COIN_API=/ENV_COIN_API=127.0.0.1:18443/g' systemd/sphinx-plugin.service
  sed -i '/ENV_COIN_API=/a\Environment="ENV_COIN_NET=test"' systemd/sphinx-plugin.service
  sed -i '/ENV_COIN_API=/a\Environment="ENV_COIN_TYPE=BTC"' systemd/sphinx-plugin.service
  cp cmd/sphinx-plugin/SphinxPlugin.viper.yaml /etc/SphinxPlugin
  cp systemd/sphinx-plugin.service /etc/systemd/system
  export GOPROXY=https://goproxy.cn
  make verify
  rm -rf /opt/sphinx-plugin/sphinx-plugin
  cp output/linux/amd64/sphinx-plugin /opt/sphinx-plugin/
}

install_btc

systemctl stop sphinx-plugin
install_sphinx_plugin
systemctl start sphinx-plugin
systemctl enable sphinx-plugin
