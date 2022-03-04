---
title : "Kind添加私有仓库自签名CA证书"
Tags : ["kind", "docker", "kubernetes", "k8s","selfsigned","ca","certificate","registry","x509"]
date : 2020-07-20T10:20:16+08:00
Categories : ["技术"]
DisqusShortname : "windyboy"
comments: true
---

## 概况
在开发环境中安装[kind][]以后，如果要部署私有仓库中的镜像，需要把自签名的根证书添加到信任列表中。
否则需要使用[kind][] load命令手动从主机把镜像加载到容器当中，不能自动部署，略嫌麻烦。

## 问题
在部署私有镜像仓库中的镜像的时候发生错误："x509: certificate signed by unknown authority"

## 解决

* 查看
```
#  get container id
$ docker ps
CONTAINER ID        IMAGE                  COMMAND                  CREATED             STATUS              PORTS                       NAMES
8c52432697b6        kindest/node:v1.18.2   "/usr/local/bin/entr…"   3 days ago          Up 4 hours          127.0.0.1:39147->6443/tcp   kind-control-plane
# attach
$ docker exec -it 8c52432697b6 /bin/bash
root@kind-control-plane:/# cat /etc/issue
Ubuntu 19.10 \n \l
```
发现是ubuntu 19
于是问题可以解决，要么把主机中含有自签名ca的信任列表Mount到容器中，要么在容器中添加自签名ca证书即可。
* 添加ca证书
```
root@kind-control-plane:/# mkdir /usr/local/share/ca-certificates/company
root@kind-control-plane:/# exit

$ docker cp your-ca.crt 8c52432697b6:/usr/share/etc/ca-certificates/company/

$ docker exec -it 8c52432697b6 /bin/bash

root@kind-control-plane:/# update-ca-certificates

# verify
root@kind-control-plane:/# curl https://your-private-registry
```

## 参考
* How to install certificates for command line https://askubuntu.com/questions/645818/how-to-install-certificates-for-command-line

[kind]: https://kind.sigs.k8s.io/ "kind"