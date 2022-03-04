---
title: "Drone CI 解决自签名证书的信任问题"
date: 2020-08-28T12:39:12+08:00
draft: false
comments: true
images:
Categories: ["技术"]
Tags: ["drone","x509","devops"]
---
##  概述
自建的系统如果没有使用公网资源，多数都是采用自签名的方式发放证书。最大的问题几乎就是自签名的信任问题，几乎成了自建工作环境最大的痛。大家都以为把主机的证书挂载到runner上就可以解决问题，**然而并不行**

## 问题
1. clone 的过程中，证书不信任
2. push docker 镜像， release 发布证书不信任

## 解决方法
### clone
如果不是把clone作为一个step，可以直接使用skip_verify: true忽略验证
```
clone:
  tags: true
  skip_verify: true
```
当然也可以使用下面挂载主机证书的方法

### 证书不信任

1. 首先把登陆drone的用户设置成admin
   
在drone server启动的环境变量中设置
```
DRONE_USER_CREATE=username:yourgitloginname,admin:true
```

2. 把项目设置为信任项目

![trust project](/images/trust.png)

3. 把主机的证书目录挂载到执行环境中

```
- name: release-publish
    image: plugins/docker
    volumes:
      - name: certs
        path: /etc/ssl/certs

volumes:
  - name: certs
    host:
      path: /etc/ssl/certs
```