# SMARTVPN #
## 介绍 ##
SmartVPN为光宇游戏运维团队发布的一个帮助运维人员快速自动化安装OPENVPN服务的脚本，主要用于企业使用OpenVPN组网环境。

##功能 ##

 - 本地安装VPN Server
 - 远程安装VPN Client

## 包含组件 ##

    lzo-2.03           安装:/usr/local           配置:null
    openssl-1.0.2k     安装:/usr/local/openssl   配置:null
    openvpn-2.1_rc22   安装:/usr/local/openvpn   配置:/etc/openvpn  日志:/var/log/openvpn-server/client.log
    smartvpn-x.x.x     安装:/usr/local/smartvpn  配置:null
    
## 常用命令 ##

**openvpn组件启动**

    /etc/init.d/openvpn start/stop

**smartvpn安装（SERVER安装，CLIENT安装）**

    /usr/local/smartvpn/smartvpn #交互式脚本

## 运行依赖 ##

    linux expect tools    #主要用于交互式命令的自动化（生成证书，远程SSH安装CLIENT端使用）
    
## 已测试编译环境 ##

    Red Hat Enterprise Linux Server release 6.4 (Santiago)
    
## 手动安装 ##
若特殊情况下需要手动安装，请按照以下规范进行安装

安装包内容：

    smartvpn_x.x.x
    │ smartvpn.sh                    #自动化安装脚本
    │
    └─smartvpn-package               #软件包
           init.d.openvpn            #init.d的openvpn启动文件
           lzo-2.03.tar.gz           #lzo源码包
           openssl-1.0.2k.tar.gz     #openssl源码包
           openvpn-2.1_rc22.tar.gz   #openvpn源码包
           openvpn-config.tar.gz     #openvpn配置文件
           
手动安装时及自动化安装脚本的自动逻辑

### VPN SERVER ###

**开始安装**      

复制自身(smartvpn_x.x.x)至/usr/local/smartvpn , 后期所有的操作都在/usr/local/smartvpn下操作

```shell
mkdir /usr/local/smartvpn
cp * /usr/local/smartvpn
cd /usr/local/smartvpn
```

安装 lzo-2.03.tar.gz
```shell
cd smartvpn-package
tar -zxvf lzo-2.03.tar.gz
cd lzo-2.03
./configure -prefix=/usr/local && make && make install
cd ..
rm -rf lzo-2.03.tar.gz
cd ..
```

2、安装 openssl-1.0.2k
```shell
cd smartvpn-package
tar -zxvf openssl-1.0.2k.tar.gz
cd openssl-1.0.2k
./config -prefix=/usr/local/openssl && make && make install
cd ..
rm -rf openssl-1.0.2k
cd ..
```

3、安装 openvpn-2.1_rc22.tar.gz
```shell
cd smartvpn-package
tar -zxvf openvpn-2.1_rc22.tar.gz
cd openvpn-2.1_rc22
./configure -prefix=/usr/local/openvpn && make && make install
cd ..
rm -rf openvpn-2.1_rc22
cd ..
```

4、开启转发
```shell
sed -i '/net.ipv4.ip_forward/ s/\(.*= \).*/\11/' /etc/sysctl.conf
sysctl -p
```

5、新建基础配置文件
```shell
mkdir -r /etc/openvpn
cd smartvpn-package
tar -zxvf openvpn-config.tar.gz
cp -R ./openvpn-config /etc/openvpn
rm -rf openvpn-config
cd ..
cp -r ./smartvpn-package/init.d.openvpn /etc/init.d/openvpn
sed -i "s/client/server/g" /etc/init.d/openvpn
chmod +x /etc/init.d/openvpn
```

6、生成配置文件

注意替换以下shell中的变量
 - $SERVERIP 为服务端IP
 - $SERVERIPAREA 为OPENVPN通讯网段（格式：172.31.0.0 255.255.255.0）
 - $PORT OPENVPN端口号（格式：10050）

```shell
cd /etc/openvpn/easy-rsa/
source ./vars
./clean-all
./build-ca #全部回车
./build-key-server server #除输入两个y外全部回车
./build-dh
cp ./keys/server.* /etc/openvpn/keys
cp ./keys/*.pem /etc/openvpn/keys
cp ./keys/ca* /etc/openvpn/keys
sed -i "s/#LOCALIP#/$SERVERIP/g" /etc/openvpn/server.conf
sed -i "s/#PORT#/$PORT/g" /etc/openvpn/server.conf
sed -i "s/#SERVERIPAREA#/$SERVERIPAREA/g" /etc/openvpn/server.conf
sed -i "s/#SERVERIP#/$SERVERIP/g" /etc/openvpn/client-conf/client.conf
sed -i "s/#PORT#/$PORT/g" /etc/openvpn/client-conf/client.conf
```

7、启动OPENVPN
```shell
/etc/init.d/openvpn start
```

**配置文件**

    /etc/openvpn
    ├── ccd                CCD文件夹
    │   └── CLIENT_110     CLIENT_110文件（当且仅当存在CLIENT时存在）
    ├── client-conf        CLIENT相关文件
    │   ├── CLIENT_110     CLIENT_110文件夹（当且仅当存在CLIENT时存在）
    │   └── client.conf    CLIENT模板文件
    ├── easy-rsa           rsa文件夹，默认为2.0
    ├── ipp.txt
    ├── keys               SERVER端的KEY文件
    │   ├── 01.pem
    │   ├── ca.crt
    │   ├── ca.key
    │   ├── dh1024.pem
    │   ├── server.crt
    │   ├── server.csr
    │   └── server.key
    └── server.conf        SERVER配置文件


**生成CLIENT配置文件**

注意：CLIENT配置文件必须在SERVER机器上生成，CLIENT_$CLIENTID为自定义

```shell
cd /etc/openvpn/easy-rsa/
source ./vars
./build-key CLIENT_$CLIENTID  #除输入两个y外全部回车
mkdir -p /etc/openvpn/client-conf/CLIENT_$CLIENTID/keys
cp ./keys/CLIENT_$CLIENTID* /etc/openvpn/client-conf/CLIENT_$CLIENTID/keys
cp ./keys/ca.crt /etc/openvpn/client-conf/CLIENT_$CLIENTID/keys
cp /etc/openvpn/client-conf/client.conf /etc/openvpn/client-conf/CLIENT_$CLIENTID/
mv /etc/openvpn/client-conf/CLIENT_$CLIENTID/keys/CLIENT_$CLIENTID.crt /etc/openvpn/client-conf/CLIENT_$CLIENTID/keys/client.crt
mv /etc/openvpn/client-conf/CLIENT_$CLIENTID/keys/CLIENT_$CLIENTID.csr /etc/openvpn/client-conf/CLIENT_$CLIENTID/keys/client.csr
mv /etc/openvpn/client-conf/CLIENT_$CLIENTID/keys/CLIENT_$CLIENTID.key /etc/openvpn/client-conf/CLIENT_$CLIENTID/keys/client.key
```

至此 /etc/openvpn/client_conf/CLIENT_$CLIENTID 下即CLIENT配置文件


### VPN CLIENT ###

**开始安装**
复制自身(smartvpn_x.x.x)至/usr/local/smartvpn , 后期所有的操作都在/usr/local/smartvpn下操作

```shell
mkdir /usr/local/smartvpn
cp * /usr/local/smartvpn
cd /usr/local/smartvpn
```

安装 lzo-2.03.tar.gz
```shell
cd smartvpn-package
tar -zxvf lzo-2.03.tar.gz
cd lzo-2.03
./configure -prefix=/usr/local && make && make install
cd ..
rm -rf lzo-2.03.tar.gz
cd ..
```

2、安装 openssl-1.0.2k
```shell
cd smartvpn-package
tar -zxvf openssl-1.0.2k.tar.gz
cd openssl-1.0.2k
./config -prefix=/usr/local/openssl && make && make install
cd ..
rm -rf openssl-1.0.2k
cd ..
```

3、安装 openvpn-2.1_rc22.tar.gz
```shell
cd smartvpn-package
tar -zxvf openvpn-2.1_rc22.tar.gz
cd openvpn-2.1_rc22
./configure -prefix=/usr/local/openvpn && make && make install
cd ..
rm -rf openvpn-2.1_rc22
cd ..
```

4、开启转发
```shell
sed -i '/net.ipv4.ip_forward/ s/\(.*= \).*/\11/' /etc/sysctl.conf
sysctl -p
```

5、新建基础配置文件
```shell
mkdir -r /etc/openvpn

# 拷贝服务端生成的配置文件（/etc/openvpn/client_conf/CLIENT_$CLIENTID/*）

cd /usr/local/smartvpn
cp -r ./smartvpn-package/init.d.openvpn /etc/init.d/openvpn
chmod +x /etc/init.d/openvpn
```

6、启动OPENVPN
```shell
/etc/init.d/openvpn start
```