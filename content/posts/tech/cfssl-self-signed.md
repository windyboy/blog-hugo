---
title: "使用CFSSL证书的生成"
date: 2022-03-02T15:40:47+08:00
# draft: true
comments: true
images:
Categories: ["技术"]
Tags: ["cfssl","x509","selfsigned","ssl","certificates"]
---

## 概述

在公司内网部署环境的时候总需要SSL的支持，其实最理想的情况是使用[letsencrypt]的服务。
在没有外网条件的时候只能采用自生成的方案。

最初的时候使用[openssl]的[easyrsa]生成，后来一直想找一个更好一点的工具，如果直接搜索的话，会查到[cert-manager]，感觉又不太合适。

直到看到[cfssl]，感觉完美契合要求


## 安装

### 从源码安装

软件使用[go]语言编写, 需要先安装，此处省略[go]的安装。

* 编译：
  
```
$ git clone git@github.com:cloudflare/cfssl.git
$ cd cfssl
$ make
```

* 编译后生成可执行文件


```
tree bin
bin
├── cfssl
├── cfssl-bundle
├── cfssl-certinfo
├── cfssljson
├── cfssl-newkey
├── cfssl-scan
├── mkbundle
├── multirootca
└── rice
```

## 生成

自签名证书一般分为三个部分，首先是根证书CA，然后是根证书签名的中间发证，最后是服务器证书。

### 1. 生成根证书 root ca

生成默认配置

```
$ cfssl print-defaults config > ca-config.json
$ cfssl print-defaults csr > ca-csr.json

$ vim ca-config.json
{
    "signing": {
        "default": {
            "expiry": "168h"
        },
        "profiles": {
                "intermediate": {
                        "usages": ["cert sign", "crl sign"],
                        "expiry": "70080h",
                        "ca_constraint": {
                                "is_ca": true,
                                "max_path_len": 1
                         }
                },
                "host": {
                        "usages": [
                                "signing",
                                "digital signing",
                                "key encipherment",
                                "server auth"
                        ],
                        "expiry": "8760h"
            }
        }
    }
}

```
修改ca-config.json，2个profile，一个是证书签发的itermediate，一个是服务器证书host

根证书的配置
```
cat ca-csr.json
{
    "CN": "example.net",
    "hosts": [
        "example.net",
        "www.example.net"
    ],
    "key": {
        "algo": "ecdsa",
        "size": 256
    },
    "names": [
        {
            "C": "US",
            "ST": "CA",
            "L": "San Francisco"
        }
    ]
}
```
修改根证书的相关信息

生成
```
mkdir root
cfssl gencert -initca ca-csr.json \
| cfssljson -bare root/root-ca

root
├── root-ca.csr
├── root-ca-key.pem
└── root-ca.pem
```

### 2. 生成证书签发

```
$ mkdir intermediate
$ vim intermediate/intermediate-csr.json
{
  "CN": "example.net CA",
  "key": {
    "algo": "ecdsa",
    "size": 256
  },
  "names": [
    {
      "C": "US",
      "ST": "CA",
      "L": "San Francisco"
    }
  ]
}

$ cfssl genkey intermediate/intermediate-csr.json \
| cfssljson -bare intermediate/intermediate-ca

$ cfssl sign -ca root/root-ca.pem \
  -ca-key root/root-ca-key.pem \
  -config ca-config.json \
  -profile intermediate \
  intermediate/intermediate-ca.csr \
| cfssljson -bare intermediate/intermediate-ca

$ tree intermediate
intermediate
├── intermediate-ca.csr
├── intermediate-ca-key.pem
├── intermediate-ca.pem
└── intermediate-csr.json
```

### 3.使用签发机构的证书签发服务器证书

```
$ mkdir server
$ cp ca-csr.json server/server-csr.json
$ vim server/server-csr.json
{
    "CN": "example.net",
    "hosts": [
        "example.net",
        "*.example.net",
        "localhost"
    ],
    "key": {
        "algo": "ecdsa",
        "size": 256
    },
    "names": [
        {
            "C": "US",
            "ST": "CA",
            "L": "San Francisco"
        }
    ]
}

```
根据实际情况修改server-csr.json, 这个就是服务器证书，对应到需要的域名

```
$ cfssl gencert \
  -ca intermediate/intermediate-ca.pem \
  -ca-key intermediate/intermediate-ca-key.pem \
  -config ca-config.json \
  -profile host \
  server/server.json \
| cfssljson -bare server/server

$ tree server
server
├── server.csr
├── server.json
├── server-key.pem
└── server.pem

```

### 4. 生成chain，包含签发的证书

```
$ cat server/server.pem intermediate/intermediate-ca.pem \
> server/fullchain.pem
```

### 5. 测试证书

```
$ openssl x509 -in server/server.pem -text -noout
```

检查证书和key是否匹配

```
$ openssl x509 -noout -modulus -in server/server.pem | openssl md5

$ openssl x509 -noout -modulus -in server/fullchain.pem | openssl md5

$ openssl rsa -noout -modulus -in server/server-key.pem | openssl md5
```

## 安装

### nginx

```
ssl_certificate fullchain.pem;
ssl_certificate_key server-key.pem;
```

### apache
```
SSLCertificateFile      server.pem  
SSLCertificateKeyFile server-key.pem
SSLCertificateChainFile fullchain.pem
```


## 参考
* [cfssl]源码 https://github.com/cloudflare/cfssl
* private ca with cfssl https://www.ekervhen.xyz/posts/2021-02/private-ca-with-cfssl/
* build ca pki with cfssl https://computingforgeeks.com/build-pki-ca-for-certificates-management-with-cloudflare-cfssl/
* verify certificate matches private key https://www.ssl247.co.uk/kb/ssl-certificates/troubleshooting/certificate-matches-private-key



[cfssl]: https://github.com/cloudflare/cfssl "CloudFlare's PKI/TLS toolkit"
[letsencrypt]: https://letsencrypt.org "letsencrypt"
[openssl]: https://openssl.org "openssl"
[easyrsa]: https://github.com/OpenVPN/easy-rsa "easyrsa"
[cert-manager]: https://cert-manager.io "cert manager"
[go]: https://go.dev "go lang"
