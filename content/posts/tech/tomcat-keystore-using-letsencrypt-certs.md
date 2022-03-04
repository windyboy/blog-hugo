+++
Categories = ["技术"]
Tags = [ "tomcat",  "ssl",  "keystore",  "letsencrypt" ]
date = "2016-09-28T16:00:00+08:00"
title = "tomcat 以 keystore 的方式使用 letsencrypt 证书"
disqus_shortname = "windyboy"
comments = true
+++

## 概况

* [apache tomcat] 应用服务器（在不使用apr连接器时）使用SSL证书的时候使用的是java专属的证书管理方式[keystore], 并不能直接使用[letsencrypt]的免费证书。
* 要把证书导入[keystore], 首先需要使用[openssl]把证书导出到.p12文件中，然后使用keytool把ca倒入为root(alias root)， 把服务器的证书导入为tomcat(alias tomcat)。

## 导入证书

* 前提

已经成功申请到有效的证书(使用[letsencrypt] 申请有效的服务器证书)。

* 使用 openssl 工具，把证书导出到.p12文件中 

```
  # openssl pkcs12 -export -in cert.pem -inkey privkey.pem \
  -out cert_and_key.p12 -name tomcat \
  -CAfile chain.pem -caname root
  Enter Export Password:
  Verifying - Enter Export Password:
```

提示输入导出密码，这里导出密码，可以直接回车，此时密码为空。 如果输入了密码，则在下面导入的时候需要输入相同的密码

* 使用keytool导入证书和ca

```
  # keytool -importkeystore \
  -deststorepass <changeit> -destkeypass <changeit> \
  -destkeystore MyDSKeyStore.jks -srckeystore cert_and_key.p12 \
  -srcstoretype PKCS12 \
  -srcstorepass <theExportPasswordAbove> -alias tomcat
```

注意deststorepass和destkeypass必须相同，否则tomcat无法获取证书

```
  # keytool -import -trustcacerts \
  -srcstorepass <theExportPasswordAbove> \
  -alias root -file chain.pem -keystore MyKeyStore.jks
```


* 配置[apache tomcat]

```
  # vim conf/server.xml
  <Connector port="443" protocol="org.apache.coyote.http11.Http11Protocol"
            maxThreads="150" SSLEnabled="true" scheme="https" secure="true"
            keystoreFile="/<path>/MyKeyStore.jks" keystorePass="<changeit>"
               clientAuth="false" sslProtocol="TLS" />
```

keystoreFile 是MyKeyStore.jks文件的绝对路径


***keystorePass 是MyKeyStore.jks的storepasss以及keypass, 必须相同***

## 参考资料

* How to use the certificate for Tomcat https://community.letsencrypt.org/t/how-to-use-the-certificate-for-tomcat/3677
* keytool - Key and Certificate Management Tool http://docs.oracle.com/javase/6/docs/technotes/tools/windows/keytool.html
* Tomcat SSL/TLS Configuration HOW-TO https://tomcat.apache.org/tomcat-7.0-doc/ssl-howto.html
* letsencrypt.sh 证书制作 https://www.hshh.org/letsencrypt/letsencrypt.sh_http-01
* 免费证书提供 https://letsencrypt.org/


## VPS 推荐
* [linode 东京] (https://www.linode.com/?r=ec0967c3fb5243693ca573d68000d3a63442ac66)
* [bandwagonhost 中国优化] (https://bandwagonhost.com/aff.php?aff=20451)
* [dgchost 新加波] (https://www.dgchost.net/client/aff.php?aff=226)


[apache tomcat]: https://tomcat.apache.org/ "apache tomcat"
[keystore]: https://docs.oracle.com/javase/7/docs/api/java/security/KeyStore.html "keystore"
[letsencrypt]: https://letsencrypt.org/ "letsencrypt"
[openssl]: https://www.openssl.org/ "openssl"