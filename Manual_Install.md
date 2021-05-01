# 使用raspberrypi 4B安装旁路由

## 1. raspberry pi 4B 准备工作

- 安装Raspberry Pi 4B 硬件

- 下载并安装烧写系统的PiImger

- (optional) 下载基于Raspberry Pi OS

- TF卡（A.K.A Micro SD）烧写Raspberry Pi OS Lite

- 连接Pi，开机

- 使用账号pi/密码raspberry登陆，之后开始准备操作

- 修改root账号的密码

  ```
  sudo su root
  passwd
  ```

- 查看硬件型号

  ```
  cat /proc/device-tree/model
  > Raspberry Pi 4 Model B Rev 1.4
  ```
  
- 修改IP地址

  ```
  # 修改IP地址为静态的192.168.31.31
  nano /etc/dhcpcd_conf
  # 手动写入下面四行
  interface eth0
  static ip_address=192.168.31.31/24
  static routers=192.168.31.1
  static domain_name_servers=192.168.31.1 8.8.8.8
  ```
  
- 启用路由转发功能

  ```
  # 设置pi的路由转发功能
  echo net.ipv4.ip_forward=1 >> /etc/sysctl.conf && sysctl -p
  # sysctl -p执行后将出现 net.ipv4.ip_forward=1 的提示
  # 这个时候网络里面的设备应该可以通过网关31不翻墙访问外网。
  ```

- 开启ssh登陆（后续步骤在ssh中完成）

  ```
  # 设置ssh连接
  # 使用下面的命令修改，或者手动 nano /etc/ssh/sshd_config 
  sed -i 's/#Port /Port /g' /etc/ssh/sshd_config
  sed -i 's/#AddressFamily /AddressFamily /g' /etc/ssh/sshd_config
  sed -i 's/#ListenAddress /ListenAddress /g' /etc/ssh/sshd_config
  sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
  sed -i 's/#PasswordAuthentication .*/PasswordAuthentication yes /g' /etc/ssh/sshd_config
  
  # 设置开机启动ssh服务
  systemctl enable ssh
  ```

- 重启

  ```
  reboot
  ```

## 2. 修改为旁路由

- 将Pi接入31.x的网络

- 在31.x的路由器上设置网关为Pi

  > OpenWRT>Network>Interface>Lan>HDCP Server>Advanced Settings>HDCP-Options 添加下面两行
  >
  > 3,192.168.31.31 # 指定网关
  >
  > 6,192.168.3.1,223.5.5.5 # 指定DNS，其实没有用最后都到31.31了。

- 测试：这个时候网络里面的设备应该可以通过网关31不翻墙访问外网。

## 3. 安装V2ray客户端

- 准备安装脚本和文件

  > 为了避免Pi访问github的不稳定，可以提前下载安装脚本和安装文件
  >
  > 脚本：https://github.com/v2fly/fhs-install-v2ray/blob/master/install-release.sh
  >
  > 文件：https://github.com/v2fly/v2ray-core/releases/download/v4.38.2/v2ray-linux-arm32-v7a.zip

- 上传文件

  ```
  scp install-release.sh root@192.168.31.31:/usr/local/
  scp v2ray-linux-arm32-v7a.zip root@192.168.31.31:/usr/local/
  ```

- 修改apt的源并更新

  ```
  # 登陆
  ssh root@192.168.31.31
  
  # 修改源
  sed -i  's/raspbian.raspberrypi.org/mirrors.ustc.edu.cn\/raspbian/g' /etc/apt/sources.list
  
  sed -i  's/archive.raspberrypi.org/mirrors.ustc.edu.cn\/raspberrypi/g' /etc/apt/sources.list.d/raspi.list
  
  # 更新apt
  apt update
  apt upgrade
  ```

  

- 启动时间同步服务

  Raspberry Pi上没有硬件时间，所以需要设置时钟同步。

  ```
  # 查看当前时间设置
  timedatectl
  
  # 修改时区
  timedatectl set-timezone Asia/Shanghai
  
  
  # 修改NTP服务器
  sed -i  's/#NTP=/NTP=ntp1.aliyun.com NTP=ntp6.aliyun.com/g' /etc/systemd/timesyncd.conf
  sed -i  's/#FallbackNTP=/FallbackNTP=/g' /etc/systemd/timesyncd.conf
  
  # 再次验证时间同步是否正常
  timedatectl
  
                 Local time: Fri 2021-04-30 22:04:31 CST 	# CST:China Standard Time
             Universal time: Fri 2021-04-30 14:04:31 UTC
                   RTC time: n/a   												# Pi没有硬件RTC
                  Time zone: Asia/Shanghai (CST, +0800) 	# timezone
  System clock synchronized: yes													# 是否成功同步
                NTP service: active												# 是否开机自动同步
            RTC in local TZ: no														
  ```

  

- 安装V2ray

  ```
  # 使用下载的脚本和软件包安装V2ray
  chmod +x install-release.sh
  ./install-release.sh --local v2ray-linux-arm32-v7a.zip
  
  
  # 先添加一个可以工作的正常客户端config.json
  nano /usr/local/etc/v2ray/config.json
  
  # 启动v2ray，并测试
  systemctl enable v2ray
  systemctl restart v2ray
  ```

- 测试客户端正常工作

  ```
  curl google.com -x socks5://127.0.0.1:1080
  ```

## 4. 设置TPROXY实现透明代理

- 设置iptable

  ```
  chmod +x config_iptable.sh
  ./config_iptable.sh
  ```

- V2ray中设置TProxy

  ```
  # 修改V2ray和iptable
  cp /usr/local/v2pi/script/v2ray.config.json /usr/local/etc/v2ray/config.json
  
  systemctl restart v2ray
  curl google.com
  ```

- 设置开机自动服务

  ```
  chmod +x config_tproxy.sh
  ./config_tproxy.sh
  ```

- 重启系统，并测试

  ```
  reboot
  
  ssh root@192.168.31.31
  curl google.com
  ```

- 同一个路由器下的其他客户端测试

  连接上同一个路由器，检查网关是否是31.31

  网页是否能打开google.com

## 5. 设置prometheus监控

- 下载prometheus

  ```
  wget https://github.com/prometheus/prometheus/releases/download/v2.26.0/prometheus-2.26.0.linux-armv7.tar.gz
  ```

  > 这个时候已经可以直接从Pi上下载github了。

  ```
  tar xfz prometheus-2.26.0.netbsd-armv7.tar.gz 
  mv prometheus-2.26.0.netbsd-armv7 prometheus
  rm prometheus-2.26.0.netbsd-armv7.tar.gz 
  ```

- 添加系统服务

  ```
  # 添加系统服务
  cat>/etc/systemd/system/prometheus.service<<-EOF
  [Unit]
  Description=Prometheus Server
  Documentation=https://prometheus.io/docs/introduction/overview/
  After=network-online.target
  
  [Service]
  User=root
  Restart=on-failure
  
  ExecStart=/usr/local/prometheus/prometheus \
    --config.file=/usr/local/prometheus/prometheus.yml \
    --storage.tsdb.path=/usr/local/prometheus/data
  
  [Install]
  WantedBy=multi-user.target
  EOF
  
  # 设置开机启动
  systemctl enable prometheus
  
  # 测试是否正常工作
  reboot
  ```

- 测试是否正常工作

  访问 http://192.168.31.31:9090/

- 安装node-export

  ```
  mkdir /opt/node-exporter
  cd /opt/node-exporter
  wget -O node-exporter.tar.gz https://github.com/prometheus/node_exporter/releases/download/v1.1.2/node_exporter-1.1.2.linux-armv7.tar.gz
  tar -xvf node-exporter.tar.gz --strip-components=1
  rm node-exporter.tar.gz
  ```

- 测试node_exporter

  ```
  ./node_exporter
  ```

  然后访问http://192.168.31.31:9100/

- 设置开机服务

  ```
  cat>/etc/systemd/system/nodeexporter.service<<-EOF
  [Unit]
  Description=Prometheus Node Exporter
  Documentation=https://prometheus.io/docs/guides/node-exporter/
  After=network-online.target
  
  [Service]
  User=root
  Restart=on-failure
  
  ExecStart=/opt/node-exporter/node_exporter
  
  [Install]
  WantedBy=multi-user.target
  EOF
  ```

- 安装grafana

  ```
  sudo apt-get install -y adduser libfontconfig1
  wget https://dl.grafana.com/oss/release/grafana_7.5.5_armhf.deb
  sudo dpkg -i grafana_7.5.5_armhf.deb
  
  systemctl daemon-reload
  systemctl enable grafana-server
  ```

- 连接prometheus数据源

  访问http://192.168.31.31:3000/

  选择数据库>类型prometheus>修改URL为http://192.168.31.31:9090

- 显示node1的数据

  右边栏导入>9276编号>选择数据源prometheus> 分组名称=node1

- 允许匿名登陆grafana直接看报表

  ```
  nano /etc/grafana/grafana.ini
  
  # 找到auth anonymous的第一个
  ;enable = false # 修改为true
  
  systemctl daemon-reload 
  systemctl restart grafana
  ```

  