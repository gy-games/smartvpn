#!/bin/bash
echo "┌──────────────────────────────────────────────────────────────────────┐"
echo "│                              SMARTVPN                                │"
echo "├──────────────────────────────────────────────────────────────────────┤"
echo "│SMARTVPN IS A SHELL SCRIPT THAT HELP OPS SETUP OPENVPN SERVICE EASIER │"
echo "│                                                                      │"
echo "│                         VERSION : 0.0.1                              │"
echo "│                                                                      │"
echo "│SCRIPT INCLUDE:                                                       │"
echo "│  lzo-2.03          INSTALL /usr/local           CONFIG null          │"
echo "│  openssl-1.0.2k    INSTALL /usr/local/openssl   CONFIG null          │"
echo "│  openvpn-2.1_rc22  INSTALL /usr/local/openvpn   CONFIG /etc/openvpn  │"
echo "│  smartvpn-0.0.1    INSTALL /usr/local/smartvpn  CONFIG null          │"
echo "│                                                                      │"
echo "│SCRIPT DEPEND:                                                        │"
echo "│  linux expect tool                                                   │"
echo "│                                                                      │"
echo "│QUICK USE                                                             │"
echo "│  /etc/init.d/openvpn start/stop                                      │"
echo "│  /usr/local/smartvpn/smartvpn #interactive                           │"
echo "│                                                                      │"
echo "│                                                 PoweredBy GyyxOpTeam │"
echo "└──────────────────────────────────────────────────────────────────────┘"

workdir=/usr/local/smartvpn
openvpnport=10050
openserveriparea="172.31.0.0 255.255.255.0"

#server software install
serversoftinstall(){
  cd $workdir
  echo "SETUP LZO.."
  cd smartvpn-package
  tar -zxvf lzo-2.03.tar.gz
  cd lzo-2.03
  ./configure -prefix=/usr/local && make && make install
  cd ..
  rm -rf lzo-2.03

  echo "SETUP OPENSSL.."
  tar -zxvf openssl-1.0.2k.tar.gz
  cd openssl-1.0.2k
  ./config -prefix=/usr/local/openssl && make && make install
  cd ..
  rm -rf openssl-1.0.2k

  echo "SETUP OPENVPN.."
  tar -zxvf openvpn-2.1_rc22.tar.gz
  cd openvpn-2.1_rc22
  ./configure -prefix=/usr/local/openvpn && make && make install
  cd ..
  rm -rf openvpn-2.1_rc22
}

#client software install 
clientsoftinstall() {

  echo "REMOTE SETUP LZO.."
  expect <<!
  set timeout 120
  spawn ssh -p $CLIENTPORT -t root@$CLIENTIP "cd /usr/local/smartvpn/smartvpn-package/ && tar -zxvf lzo-2.03.tar.gz && cd lzo-2.03 && ./configure -prefix=/usr/local && make && make install && cd .. && rm -rf lzo-2.03"
  expect {
    "password" { send "$ROOTPWD\r"; exp_continue}
  }
!

  echo "REMOTE SETUP OPENSSL"
  expect <<!
  set timeout 200
  spawn ssh -p $CLIENTPORT -t root@$CLIENTIP "cd /usr/local/smartvpn/smartvpn-package/ && tar -zxvf openssl-1.0.2k.tar.gz && cd openssl-1.0.2k && ./config -prefix=/usr/local/openssl && make && make install && cd .. && rm -rf openssl-1.0.2k"
  expect {
    "password" { send "$ROOTPWD\r"; exp_continue} 
  }
!

  echo "REMOTE SETUP OPENVPN"
  expect <<!
  set timeout 200
  spawn ssh -p $CLIENTPORT -t root@$CLIENTIP "cd /usr/local/smartvpn/smartvpn-package/ && tar -zxvf openvpn-2.1_rc22.tar.gz && cd openvpn-2.1_rc22  && ./configure -prefix=/usr/local/openvpn  && make && make install && cd .. && rm -rf openvpn-2.1_rc22"
  expect {
    "password" { send "$ROOTPWD\r"; exp_continue} 
  }
!
}


serverinit() {
  echo "--------OPENVPN SERVER PREPARE TO SETUP----------"
  echo "SYSTEM INIT.."
  sed -i '/net.ipv4.ip_forward/ s/\(.*= \).*/\11/' /etc/sysctl.conf
  sysctl -p
  serversoftinstall
  cd $workdir
  echo "CONFIG INIT.."
  mkdir -r /etc/openvpn
  cd smartvpn-package
  tar -zxvf openvpn-config.tar.gz
  cp -R ./openvpn-config /etc/openvpn
  rm -rf openvpn-config
  cd ..
  cp -r ./smartvpn-package/init.d.openvpn /etc/init.d/openvpn
  sed -i "s/client/server/g" /etc/init.d/openvpn
  chmod +x /etc/init.d/openvpn
  #rm /etc/openvpn/client.conf
  cd /etc/openvpn/easy-rsa/
  source ./vars
  ./clean-all

  expect <<!
  set timeout 10
  spawn ./build-ca
  expect {
    "]" { send "\r"; exp_continue}
  }
!
  echo "CA CREATE SEUCCESS!"
  #sleep 2
  expect <<!
  set timeout 20
  spawn ./build-key-server server
  expect "*"
  send "\r"
  expect "*"
  send "\r"
  expect "*"
  send "\r"
  expect "*"
  send "\r"
  expect "*"
  send "\r"
  expect "*"
  send "\r"
  expect "*"
  send "\r"
  expect "*"
  send "\r"
  expect "*"
  send "\r"
  expect "*"
  send "\r"
  expect "*"
  send "y\r"
  expect "*"
  send "y\r"
  expect eof
!
  echo "SERVER KEY CREATE SUCCESS!"
  #sleep 3
  ./build-dh
  #mkdir /etc/openvpn/server_key
  cp ./keys/server.* /etc/openvpn/keys
  cp ./keys/*.pem /etc/openvpn/keys
  cp ./keys/ca* /etc/openvpn/keys
  sed -i "s/#LOCALIP#/$SERVERIP/g" /etc/openvpn/server.conf
  sed -i "s/#PORT#/$PORT/g" /etc/openvpn/server.conf
  sed -i "s/#SERVERIPAREA#/$SERVERIPAREA/g" /etc/openvpn/server.conf
  sed -i "s/#SERVERIP#/$SERVERIP/g" /etc/openvpn/client-conf/client.conf
  sed -i "s/#PORT#/$PORT/g" /etc/openvpn/client-conf/client.conf

}

clientinit() {
  echo "--------OPENVPN CLIENT PREPARE TO SETUP----------"
  echo "SYSTEM INIT.."
  expect <<!
  spawn ssh -p $CLIENTPORT -t root@$CLIENTIP "sed -i '/net.ipv4.ip_forward/ s/\\\(.*= \\\).*/\\\11/' /etc/sysctl.conf && sysctl -p"
  expect {
    "password" { send "$ROOTPWD\r"; exp_continue} 
  }
!
  clientsoftinstall
  cd /etc/openvpn/easy-rsa/
  source ./vars
  expect <<!
  spawn ./build-key CLIENT_$CLIENTID
  expect "*"
  send "\r"
  expect "*"
  send "\r"
  expect "*"
  send "\r"
  expect "*"
  send "\r"
  expect "*"
  send "\r"
  expect "*"
  send "\r"
  expect "*"
  send "\r"
  expect "*"
  send "\r"
  expect "*"
  send "\r"
  expect "*"
  send "\r"
  expect "*"
  send "y\r"
  expect "*"
  send "y\r"
  expect eof
!
  mkdir -p /etc/openvpn/client-conf/CLIENT_$CLIENTID/keys
  cp ./keys/CLIENT_$CLIENTID* /etc/openvpn/client-conf/CLIENT_$CLIENTID/keys
  cp ./keys/ca.crt /etc/openvpn/client-conf/CLIENT_$CLIENTID/keys
  cp /etc/openvpn/client-conf/client.conf /etc/openvpn/client-conf/CLIENT_$CLIENTID/
  mv /etc/openvpn/client-conf/CLIENT_$CLIENTID/keys/CLIENT_$CLIENTID.crt /etc/openvpn/client-conf/CLIENT_$CLIENTID/keys/client.crt
  mv /etc/openvpn/client-conf/CLIENT_$CLIENTID/keys/CLIENT_$CLIENTID.csr /etc/openvpn/client-conf/CLIENT_$CLIENTID/keys/client.csr
  mv /etc/openvpn/client-conf/CLIENT_$CLIENTID/keys/CLIENT_$CLIENTID.key /etc/openvpn/client-conf/CLIENT_$CLIENTID/keys/client.key
 
  expect <<!
  spawn scp -r -P $CLIENTPORT $workdir/smartvpn-package/init.d.openvpn root@$CLIENTIP:/etc/init.d/openvpn
  expect {
    "password" { send "$ROOTPWD\r"; exp_continue}
  }
!
 expect <<!
  set timeout 20
  spawn ssh -p $CLIENTPORT -t root@$CLIENTIP "mkdir -r /etc/openvpn"
  expect {
    "password" { send "$ROOTPWD\r"; exp_continue} 
  }
!
  expect <<!
  spawn scp -r -P $CLIENTPORT /etc/openvpn/client-conf/CLIENT_$CLIENTID root@$CLIENTIP:/etc/openvpn
  expect {
    "password" { send "$ROOTPWD\r"; exp_continue}
  }
!
 expect <<!
  set timeout 20
  spawn ssh -p $CLIENTPORT -t root@$CLIENTIP "chmod +x /etc/init.d/openvpn"
  expect {
    "password" { send "$ROOTPWD\r"; exp_continue} 
  }
!
}

preparechech(){
  echo "PREPARE CHECKING.."
  if [ `rpm -qa | grep expect |wc -l` -eq 0 ];then
    echo "[FAIL]EXPECT PACKAGE IS NOT INSTALL , PLEASE INSTALL EXPECT FIRST!(exp:yum install expect)"
  exit
  fi
}

sysinit(){
  echo "SYSTEM INIT.."
  sed -i '/net.ipv4.ip_forward/ s/\(.*= \).*/\11/' /etc/sysctl.conf
  sysctl -p
  echo "[SUCCESS]SET IP FORWARD OK !"
}


#-------------------------------------MAIN----------------------------------------------

preparechech

read -p "WHICH SERVICE YOU WANT SETUP?( 1:SERVER,2:CLIENT ):" SOC

if [[ $SOC == "1" ]];then
  while :
  do
    read -p "PLEASE ENTER YOUR SERVER IP ADDR(THIS ADDR USE FRO CLIENT CONNECT):" SERVERIP
    regex="\b(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[1-9])\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[0-9])\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]|[1-9])\b"
    ckStep2=`echo $SERVERIP | egrep $regex | wc -l`
    if [ $ckStep2 -eq 0 ]
    then
       echo "[FAIL]THE STRING $SERVERIP IS NOT A CORRECT IPADDR,PLEASE TRY AGAIN!"
    else
       break
    fi
  done

  read -p "PLEASE ENTER YOUR OPENVPN PORT (DEFAULT:10050):" PORT
  if [ ! -n "$PORT" ];then
   PORT=$openvpnport
  fi

  read -p "PLEASE ENTER YOUR OPENVPN COMMUNICATION SUBNET (DEFAULT:172.31.0.0 255.255.255.0):" SERVERIPAREA
  if [ ! -n "$SERVERIPAREA" ];then
    SERVERIPAREA=$openserveriparea
  fi

  echo "           VERFIY YOUR CONFIGRATION!             "
  echo "                                                 "
  echo "             SERVER IP $SERVERIP                 "
  echo "             OPENVPN PORT $PORT                  "
  echo "   OPENVPN COMMUNICATION SUBNET $SERVERIPAREA    "
  echo "                                                 "
  read -p "PLEASE VIRFY YOUR CONFIG?( y/n ):" BEGIN
  if [[ $BEGIN != "y" ]];then
    exit
  fi
  rm -rf  /usr/local/smartvpn
  mkdir /usr/local/smartvpn
  cp -rf smartvpn.sh /usr/local/smartvpn
  cp -rf  smartvpn-package /usr/local/smartvpn
  #begin to install server
  serverinit
  echo "[SUCCESS]OPENVPN SERVICE SETUP FINISH,YOU CAN FIND THIS SCRIPT AT /usr/local/smartvpn"
  read -p "WOULD YOU LIKE TO START OPENVPN NOW？( y/n )" STARTSERVICE
  if [[ $STARTSERVICE == "y" ]];then
    /etc/init.d/openvpn start
  fi

elif [[ $SOC == "2" ]];then
  echo "NOTICE!! YOU MUST RUN THIS SCRIPT AT OPENVPN SERVER OR IT WILL FAIL!"
  SERVERIPADDR=`cat /etc/openvpn/server.conf  | grep local | awk {'print $2'}`
  SERVERPORT=`cat /etc/openvpn/server.conf  | grep port | awk {'print $2'}`
  read -p "PLEASE ENTER YOUR CLIENT SSH IP ADDR:" CLIENTIP
  read -p "PLEASE ENTER YOUR CLIENT SSH PORT:" CLIENTPORT
  read -p "PLEASE ENTER YOU CLIENT ROOT PASSWORD:" ROOTPWD
  read -p "PLEASE ENTER YOU CLIENT ID(demo:001):" CLIENTID
  echo "           VERFIY YOUR CONFIGRATION!             "
  echo "                                                 "
  echo "    SERVER IP:PORT $SERVERIPADDR:$SERVERPORT     "
  echo "             CLIENT IP $CLIENTIP                 "
  echo "             CLIENT ID $CLIENTID                 "
  echo "                                                 "
  read -p "PLEASE VIRFY YOUR CONFIG?( y/n ):" BEGIN
  if [[ $BEGIN != "y" ]];then
    exit
  fi
  #scp software package to client 
  expect <<!
  spawn scp -r -P $CLIENTPORT /usr/local/smartvpn root@$CLIENTIP:/usr/local
  expect {
    "password" { send "$ROOTPWD\r"; exp_continue}
  }
!
  #begin to install client
  clientinit
  echo "[SUCCESS]OPENVPN SERVICE SETUP FINISH,YOU CAN FIND THIS SCRIPT AT /usr/local/smartvpn"
  read -p "WOULD YOU LIKE TO START OPENVPN CLIENT NOW？( y/n )" STARTSERVICE
  if [[ $STARTSERVICE == "y" ]];then
  expect <<!
  spawn ssh -t -p $CLIENTPORT root@$CLIENTIP "/etc/init.d/openvpn start"
  expect {
    "password" { send "$ROOTPWD\r"; exp_continue}
  }
!
  fi

else
  echo "[FAIL]Param Error! PLEASE TRY AGAINE!"

fi
