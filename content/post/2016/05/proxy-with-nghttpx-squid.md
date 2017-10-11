+++
Categories = ["技术"]
Tags = ["nghttpx", "squid", "proxy", "http2"]
date = "2016-05-24T15:13:14+08:00"
title = "nghttpx搭配squid科学浏览"
disqus_shortname = "windyboy"
+++


## 概况

* 服务器

	服务器上部署代理工具nghttpx，缓存服务squid

	受限制网络 ==proxy==> nghttpx > squid (缓存) ==> 互联网

* 客户端

	客户端是用https proxy的方式访问服务器，同时服务端开启客户端证书认证，在客户端部署自签证书。对比ss的方式减免了客户端软件的部署。

	https proxy client ==> 服务

* 主要工具

	* https proxy 服务器 [nghttp2][]
	* 缓存服务器 [squid][]
	* 客户端证书生成工具 [easyrsa][]
	* 客户端证书导入导出 [openssl][]


## 安装

这里安装的过程以centos 7为例，其他发行版本可根据实际情况适当

```
#cat /etc/redhat-release 
CentOS Linux release 7.2.1511 (Core)
```

* 基础软件

	如果使用epel的源安装，首先安装epel 
	   
	```
	# yum install epel-release
	# yum install openssl git-core
	```


* [nghttp2][] [squid][]

	使用的代理程序是nghttpx, 安装的软件包是nghttp2，nghttp2中包含nghttpx的代理服务程序
	
	```
	# yum install nghttp2 squid
	```

	nghttp2 也可以自编译源码来安装，epel安装的版本是1.7,通过编译可以安装1.9

	>
	>```
	>sudo yum groupinstall "Development Tools"
	>sudo yum install libev libev-devel zlib zlib-devel openssl openssl-devel git
	>git clone https://github.com/nghttp2/nghttp2.git
	>cd nghttp2
	>autoreconf -i
	>automake
	>autoconf
	>./configure
	>make
	>sudo make install
	>```
	>

	默认安装位置是 ```/usr/local/bin```

	***在centos 7的环境正不能使用最新版的1.11.0-DEV，需要使用1.9.x的版本。在clone项目以后需要checkout 1.9.x的版本***

	```git checkout v1.9.x```

	然后再执行编译的操作,编译安装完成以后，检查一下版本

	```# /usr/local/bin/nghttpx -v```


* [easyrsa][]

	克隆easyrsa源码
	```
	# git clone https://github.com/OpenVPN/easy-rsa.git
	```
	把easyrsa 复制到/opt/中完成安装
	```
	# cd easy-rsa/
	# cp -r easyrsa3 /opt/
	```


## 配置

### 证书

* 服务器证书

	服务器端证书可以使用[letsencrypt][]提供的免费证书。
	配置[letsencrypt][]证书的时候可以使用[letsencrypt.sh](https://github.com/lukas2511/letsencrypt.sh)的脚本,可以简化配置的过程。

* 客户端验证证书

	客户端认证证书因为[letsencrypt](https://letsencrypt.org)不提供签发客户端证书的功能，所以需要自己做一个ca，自行签发客户端证书

* easyrsa 配置客户端证书


	```
	# cd /opt/easyrsa3
	# mv vars.example vars
	```

	编辑vars文件，去掉前面的注释，编辑中主要的变量

	```
	set_var EASYRSA_REQ_COUNTRY    "US"
	set_var EASYRSA_REQ_PROVINCE   "California"
	set_var EASYRSA_REQ_CITY       "San Francisco"
	set_var EASYRSA_REQ_ORG        "Copyleft Certificate Co"
	set_var EASYRSA_REQ_EMAIL      "me@example.net"
	set_var EASYRSA_REQ_OU         "My Organizational Unit"
	```

	生成客户端证书

	```
	# ./easyrsa init-pki
	# ./easyrsa build-ca nopass
	# ./easyrsa gen-dh
	# ./easyrsa build-client-full client-me nopass
	```

	导出CA证书

	```
	# openssl x509 -in pki/ca.crt -out ca.pem -outform PEM
	```

	导出客户端证书

	```
	# openssl pkcs12 -export -clcerts -in pki/issued/client-me.crt -inkey pki/private/client-me.key -out client-me.p12
	# openssl pkcs12 -in client-me.p12 -out client-me.pem -clcerts
	```
	客户端电脑导入ca和客户端证书
	
	最终生成ca.pem, client-me.pem两个证书文件，复制到客户端，并导入。
	ca.pem导入为可信任的证书颁发机构，client-me.pem导入为信任证书。

### 代理

* 创建nghttpx的配置文件
	```
	# mkdir /etc/nghttpx
	# touch /etc/nghttpx/nghttpx.conf
	```
* 编辑配置文件 nghttpx.conf
	```
	frontend=0.0.0.0,443;tls
	backend=127.0.0.1,3128;no-tls
	#服务器证书
	private-key-file=/etc/letsencrypt.sh/certs/[domain]/privkey.pem
	certificate-file=/etc/letsencrypt.sh/certs/[domain]/fullchain.pem
	#客户端验证
	dh-param-file=/etc/nghttpx/dh.pem
	verify-client-cacert=/etc/nghttpx/ca.pem
	#代理
	http2-proxy=yes
	no-via=yes
	no-ocsp=yes
	no-host-rewrite=yes
	add-x-forwarded-for=yes
	strip-incoming-x-forwarded-for=yes
	```

	其中[domain]为服务器的域名，privkey.pem, fullchain.pem是letsencrypt生成的服务器证书。dh.pem, ca.pem是客户端证书

* ngttpx服务
	```
	# vi /etc/systemd/system/nghttpx.service
	```
	编辑内容

	```
	[Unit] 
	Description=nghttpx 
	After=network.target 
	 
	[Service] 
	Type=simple 
	ExecStart=/usr/local/bin/nghttpx --conf=/etc/nghttpx/nghttpx.conf
	ExecReload=/bin/kill -SIGUSR1 ${MAINPID}
	ExecStop=/bin/kill -SIGQUIT ${MAINPID}
	 
	[Install] 
	WantedBy=multi-user.target
	```

	服务
	```
	# systemctl daemon-reload
	# systemctl start nghttpx
	# systemctl enable nghttpx
	```

### 缓存

通过yum安装的squid服务，默认配置基本上已经满足要求，需要做一点小修改

* 编辑配置
	```
	# vi /etc/squid/squid.conf
	```

	在配置文件尾部加上
	```
	via off
	forwarded_for delete
	access_log none
	```

* 重启服务
	```
	# systemctl restart squid
	```

## 参考资料
* nghttpx 官方指引 https://nghttp2.org/documentation/nghttpx-howto.html
* 谷歌上另外一篇参考的nghttpx+squid https://wzyboy.im/post/1052.html
* nghttpx 的配置，证书，服务脚本 https://blog.apar.jp/linux/2584/
* centos 编译 nghttp2 https://gist.github.com/sonots/2bdf6cd26c23ef44db71
* letsencrypt.sh 证书制作 https://www.hshh.org/letsencrypt/letsencrypt.sh_http-01
* 免费证书提供 https://letsencrypt.org/ 
* client 证书生成 https://gist.github.com/mtigas/952344

## VPS 推荐
* [linode 东京] (https://www.linode.com/?r=ec0967c3fb5243693ca573d68000d3a63442ac66)
* [bandwagonhost 中国优化] (https://bandwagonhost.com/aff.php?aff=20451)
* [dgchost 新加波] (https://www.dgchost.net/client/aff.php?aff=226)

[nghttp2]: https://nghttp2.org "nghttp2"
[squid]: http://www.squid-cache.org "squid"
[easyrsa]: https://github.com/OpenVPN/easy-rsa "easyrsa"
[openssl]: https://www.openssl.org "openssl"
[letsencrypt]: https://letsencrypt.org "letsencrypt"




