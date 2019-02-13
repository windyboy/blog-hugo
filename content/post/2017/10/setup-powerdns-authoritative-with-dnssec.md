+++
Categories = ["技术"]
Tags = ["dns", "dnssec", "powerdns","postgresql", "authoritative", "cloudxns"]
date = "2017-10-09T16:00:00+08:00"
title = "使用powerdns搭建自己安全的域名解析服务"
disqusShortname = "windyboy"

+++

## 概况

* 起因： [cloudxns]停止了面向个人的服务 
* 解析服务需要提供两个独立的IP，一主一从提供解析服务
* 两个服务器IP地址要注册到域名注册商的服务里，解决先有鸡还是先有蛋的问题
* DNSSEC的key也要注册到注册商
* 使用[postgresql]替代[mariadb]原因在于，在目前这个版本中，日志里总是出现连接断开的警告

## 安装软件


**两台服务器都安装相同的软件, authoritative 和 database**

### 从官方的[repo](https://repo.powerdns.com/)安装authoritative服务软件 



* 创建pdns的源

```
# vim /etc/apt/sources.list.d/pdns.list

deb [arch=amd64] http://repo.powerdns.com/debian stretch-auth-master main
```

* 屏蔽debian自带的pdns

```
# vim /etc/apt/preferences.d/pdns 
Package: pdns-*
Pin: origin repo.powerdns.com
Pin-Priority: 800
```

* 引入官方的key

```
# curl https://repo.powerdns.com/FD380FBB-pub.asc | apt-key add - 
```

* 安装服务器软件


```
# apt-get update
# apt-get install pdns-server
```

***其他的系统可以到 https://repo.powerdns.com/ 参考响应的安装指引***

### 安装数据库

* 安装postgresql

```
# apt install postgresql postgresql-client
```

* 初始化数据库账号

```
# sudo -u postgres psql
postgres=# create user pdns with password 'mypdnspassword';
postgres=# create database pdns owner pdns;
postgres=# grant all privileges on database pdns to pdns;
postgres=# \q
```

* 安装powerdns的backend

```
# apt install pdns-backend-pgsql
```
安装过程中会询问数据库用户的信息，根据前面初始化的用户名/密码，填入即可

* 建立主从数据的复制

在从服务器上执行

```
# psql -U pdns -d pdns -h 127.0.0.1 -p 5432

pdns=> \i /usr/share/doc/pdns-backend-pgsql/schema.pgsql.sql
pdns=> insert into supermasters (ip, nameserver, account) values ('x.x.x.x1', 'ns2.some.host','admin');
pdns=> insert into domains (name, master, type) values ('some.host', 'x.x.x.x1', 'SLAVE');
pdns=>\q

# systemctl restart pdns
```
x.x.x.x1 是主服务器的IP地址

### 安装 [Powerdns-Admin]

**管理界面只安装在主服务器上**

* 安装基础设施

```
# apt install -y libmysqlclient-dev libsasl2-dev libldap2-dev libssl-dev libxml2-dev libxslt1-dev libxmlsec1-dev libffi-dev pkg-config apt-transport-https virtualenv build-essential
# curl -sL https://deb.nodesource.com/setup_10.x | bash -
# apt-get install -y nodejs
# curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
# echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
# apt update -y
# apt install -y yarn
# apt install nginx
```

* 创建数据库

```
$ sudo su - postgres
$ createuser powerdnsadmin
$ createdb powerdnsadmindb
$ psql
postgres=# alter user powerdnsadmin with encrypted password 'powerdnsadmin';
postgres=# grant all privileges on database powerdnsadmindb to powerdnsadmin;
```

* 安装软件

```
# git clone https://github.com/ngoduykhanh/PowerDNS-Admin.git /opt/web/powerdns-admin
# cd /opt/web/powerdns-admin
# virtualenv -p python3 flask
# source ./flask/bin/activate
# pip install -r requirements.txt
# pip install psycopg2
# cp config_template.py config.py

```


* 数据库配置

```
# vi config.py
SQLALCHEMY_DATABASE_URI = 'postgresql://powerdnsadmin:powerdnsadmin@127.0.0.1/powerdnsadmindb'
```


* 运行

```
# export FLASK_APP=app/__init__.py
# flask db upgrade
# yarn install --pure-lockfile
# flask assets build
# ./run.py
```

* 安装服务

```
# groupadd powerdnsadmin
# useradd --system --user-group powerdnsadmin
# vim /etc/systemd/system/powerdns-admin.service

[Unit]
Description=PowerDNS-Admin
After=network.target

[Service]
Type=simple
User=powerdnsadmin
Group=powerdnsadmin
ExecStart=/opt/web/powerdns-admin/flask/bin/gunicorn --workers 2 --bind unix:/opt/web/powerdns-admin/powerdns-admin.sock app:app
WorkingDirectory=/opt/web/powerdns-admin
Restart=always

[Install]
WantedBy=multi-user.target

# systemctl daemon-reload
# systemctl start powerdns-admin
# systemctl enable powerdns-admin
```

* 配置反向代理

```
# vim /etc/nginx/sites-available/pdns

server {
    server_name pdns.some.local ;
    listen 80;
      index                     index.html index.htm index.php;
  root                      /opt/web/powerdns-admin;
  access_log                /var/log/nginx/powerdns-admin.local.access.log combined;
  error_log                 /var/log/nginx/powerdns-admin.local.error.log;

  client_max_body_size              10m;
  client_body_buffer_size           128k;
  proxy_redirect                    off;
  proxy_connect_timeout             90;
  proxy_send_timeout                90;
  proxy_read_timeout                90;
  proxy_buffers                     32 4k;
  proxy_buffer_size                 8k;
  proxy_set_header                  Host $host;
  proxy_set_header                  X-Real-IP $remote_addr;
  proxy_set_header                  X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_headers_hash_bucket_size    64;

  location ~ ^/static/  {
    include  /etc/nginx/mime.types;
    root /opt/web/powerdns-admin/app;

    location ~*  \.(jpg|jpeg|png|gif)$ {
      expires 365d;
    }

    location ~* ^.+.(css|js)$ {
      expires 7d;
    }
  }

  location / {
    proxy_pass            http://unix:/opt/web/powerdns-admin/powerdns-admin.sock;
    proxy_read_timeout    120;
    proxy_connect_timeout 120;
    proxy_redirect        off;
  }
}

# ln -s /etc/nginx/sites-available/pdns /etc/nginx/sites-enabled/pdns
# nginx -t
# systemctl restart nginx
```

* 使用Git安装软件

```
# git clone https://github.com/poweradmin/poweradmin.git /var/www/html/pdns/
# chown -R www-data: /var/www/html/pdns/
# sudo service nginx reload
```

* 打开PowerDNS的API

```
# vi /etc/powerdns/pdns.conf
#4.0 
webserver=yes
api=yes
api-key=somekey

# systemctl restart pdns
```

* 打开网页, 注册新用户并登陆

```
打开 API 设置页面，连接到主服务器
http://pdns.some.host/admin/setting/pdns

PDNS API URL: http://localhost:8081
PDNS API KEY: somekey

```



## 配置服务

### 配置主机环境

* 配置主机host文件，强制解析 ns1, ns2
```
# vim /etc/hosts
x.x.x.x1   ns1.some.host
x.x.x.x2   ns2.some.host
```
两台解析服务器都使用相同配置

* 分别在两台主机验证

```
# ping ns1.some.host
# ping ns2.some.host
```

* 配置[powerdns]配置文件

在主服务器(ns1.some.host)上配置
```
# vim /etc/powerdns/pdns.conf

config-dir=/etc/powerdns
setuid=pdns
setgid=pdns
master=yes
slave=no
allow-axfr-ips=x.x.x.x2/32
default-soa-name=ns1.some.host
dnsupdate=yes
daemon=yes
disable-axfr=no
guardian=yes
local-address=0.0.0.0
local-port=53
log-dns-details=no
log-dns-queries=no
loglevel=9
socket-dir=/var/run
version-string=powerdns
webserver=yes
api=yes
api-key=somekey
include-dir=/etc/powerdns/pdns.d
launch=
```

其中x.x.x.x2为从服务器ns2.some.host的ip地址


在从服务器(ns2.some.host)上配置

```
# vim /etc/powerdns/pdns.conf

config-dir=/etc/powerdns
setuid=pdns
setgid=pdns
master=no
slave=yes
daemon=yes
disable-axfr=yes
guardian=yes
local-address=0.0.0.0
local-port=53
log-dns-details=no
log-dns-queries=no
loglevel=9
slave-cycle-interval=60
socket-dir=/var/run
version-string=powerdns
include-dir=/etc/powerdns/pdns.d
launch=
```


### 使用[web]界面创建 master zone

登录到[web]的网页， 选择Add master zone的菜单，进入新建向导的网页, 在zone里输入域名 some.host

点击，list zone, 选择刚才创建的some.host, 这里系统会创建SOA记录，如：

```
some.host	SOA	ns1.some.host hostmaster.some.host 2017101100 28800 7200 604800 86400
```
第一条ns1.some.host为主服务器域名

第二条hostmaster.some.host实际上是邮件地址，系统替换第一个'.'为'@', 这里代表的地址是hostmaster@some.host，具体可以根据实际情况写自己的邮箱地址

创建成功以后可以用dig命令核实一下

```
dig some.host soa @localhost
;; ANSWER SECTION:
some.host.              3600    IN      SOA     ns1.some.host. postmaster.some.host. 2017101106 28800 7200 604800 86400
```

### 创建DNSSEC记录

* 使用pdnsutil创建DNSSEC

```
pdnsutil secure-zone some.host

Securing zone with default key size
Adding CSK (257) with algorithm ecdsa256
Zone some.host secured
gpgsql Connection successful. Connected to database 'pdns' on 'localhost'.
Adding NSEC ordering information
```

* 查看已经生成的key

```
pdnsutil show-zone some.host

This is a Master zone
Last SOA serial number we notified: 2017101100 == 2017101100 (serial in the database)
Metadata items: None
Zone has NSEC semantics
keys:
ID = 10 (CSK), flags = 257, tag = 59581, algo = 13, bits = 256    Active ( ECDSAP256SHA256 )
CSK DNSKEY = some.host. IN DNSKEY 257 3 13 PQ29wza3majnpUQ+21oEkQjfpyN3dMnTy0StcnNX7YeuRRkOeddqPpFMDoeovZcpQGV0BxduvFn/Q2DW5WXp8w== ; ( ECDSAP256SHA256 )
DS = some.host. IN DS 59581 13 1 7908b7585027f7a262d664c7ee07ae5c5733d44e ; ( SHA1 digest )
DS = some.host. IN DS 59581 13 2 cfc9006e02d2a02448cd8cdde7fcb8e840703883b166685f37db5225ad902a88 ; ( SHA256 digest )
DS = some.host. IN DS 59581 13 3 67099daf0ecaf3e99c1c5dcce132c66dc201d27d2f1baade0fecbbbaa2c6b423 ; ( GOST R 34.11-94 digest )
DS = some.host. IN DS 59581 13 4 53062fef193fae2564f9f2441cb821ae3b55c92afac5790ae70cb8e9359313e0a4c879a09c44c9cb98ed68100cf2e938 ; ( SHA-384 digest )
```

* 把相关信息推送到从服务器


在主服务器上执行
```
# pdnsutil rectify-zone some.host
```

## 注册解析服务


* 注册nameserver的IP地址

打开域名注册商的网页，我这里以[namesilo]为例

点击domain manager, 再点击已经注册成功的域名(some.host)，进入域名管理界面

在NameServers部分，点击View/Manage Registered NameServers， 进入注册域名解析服务器页面

点击 REGISTER NEW NAMESERVER 按钮，分别加入ns1, ns2的IP地址


* 注册DNSSEC

回到之前域名管理的页面， 点击DS Records (DNSSEC):后面的Update连接

进入注册Key的界面， 相关信息在之前 pdnsutil show-zone some.host 的部分已经列出

```
DS = some.host. IN DS 59581 13 1 7908b7585027f7a262d664c7ee07ae5c5733d44e ; ( SHA1 digest )
```
Digest = 7908b7585027f7a262d664c7ee07ae5c5733d44e

Key Tag = 59581

Digest Type = 1

Algorithm = 13


## 检验

* 检查域名是否已在全球生效

打开网站： https://dnschecker.org/

输入域名 some.host , 检查各地的解析情况


* 使用dig在本地服务器检验DNSSEC

```
# dig some.host +dnssec +multi @localhost

;; AUTHORITY SECTION:
some.host.              86400 IN SOA ns1.some.host. hostmaster.some.host. (
                                2017101100 ; serial
                                28800      ; refresh (8 hours)
                                7200       ; retry (2 hours)
                                604800     ; expire (1 week)
                                86400      ; minimum (1 day)
                                )
some.host.              86400 IN RRSIG SOA 13 2 86400 (
                                20171019000000 20170928000000 59581 some.host.
                                UyrOyITKMWhtf2n8lN3ZhtxaAGSMFQI9Qndd49D2/Pe5
                                wWLileK3RVPFRGlXflQfFDfQ6wb7R5+aBCls6qkmIA== )
some.host.              86400 IN NSEC some.host. SOA RRSIG NSEC DNSKEY
some.host.              86400 IN RRSIG NSEC 13 2 86400 (
                                20171019000000 20170928000000 59581 some.host.
                                4fjlTftqvjmoH0OwVf3uuC8OvvuYyyIckn+c5L0J89Np
                                kc1+LCZ5DJpQrnbsWypxr5bDXARB86pr046dbrs21A== )
```

* 使用在线工具检验 DNSSEC

打开网页 https://dnssec-debugger.verisignlabs.com

输入域名 some.host



## 参考资料
* [How To Install and Configure PowerDNS with a MariaDB Backend on Ubuntu 14.04] (https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-powerdns-with-a-mariadb-backend-on-ubuntu-14-04)
* [How To Configure DNS Replication on a Slave PowerDNS Server on Ubuntu 14.04](https://www.digitalocean.com/community/tutorials/how-to-configure-dns-replication-on-a-slave-powerdns-server-on-ubuntu-14-04)
* [PowerDNS and PowerAdmin Set-up w/ Ubuntu 16.04](http://mindwatering.com/SupportRef.nsf/webpg/9F706A2177A497FE8525812D00041654) 
* 官方安装文档 https://doc.powerdns.com/authoritative/installation.html


## VPS 推荐
* [linode 东京] (https://www.linode.com/?r=ec0967c3fb5243693ca573d68000d3a63442ac66)
* [bandwagonhost 中国优化] (https://bandwagonhost.com/aff.php?aff=20451)
* [dgchost 新加波] (https://www.dgchost.net/client/aff.php?aff=226)



[powerdns]: https://powerdns.com/ "powerdns"
[postgresql]: https://www.postgresql.org/ "postgresql"
[mariadb]: https://mariadb.org/ "mariadb"
[cloudxns]: https://www.cloudxns.net/ "cloudxns"
[powerdns-admin]: https://github.com/ngoduykhanh/PowerDNS-Admin "web"
[namesilo]: https://www.namesilo.com "namesilo"

