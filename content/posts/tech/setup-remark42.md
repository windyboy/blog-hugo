---
title: "使用 Remark42 实现自建用户留言"
date: 2020-07-24T13:56:31+08:00
draft: false
comments: true
images:
Categories: ["技术"]
Tags: ["hugo","comments","remark42","disqus"]
---

## 概况
原来使用hugo自带的disqus插件实现用户留言，默认情况下感觉要读取的东西太多，于是打算找一个替代产品
最好是自建服务，装载要比disqus快

## 选择
根据官方的指引[comments]，其实可以选择的替代品不少
> ## Comments Alternatives

> There are a few alternatives to commenting on static sites for those who do not want to use Disqus:
>
> *   [Staticman]
> *   [Talkyard] (Open source, & serverless hosting)
> *   [IntenseDebate]
> *   [Graph Comment][graphcomment]
> *   [Muut]
> *   [Isso] (Self-hosted, Python)
> *   [Utterances] (Open source, GitHub comments widget built on GitHub issues)
> *   [Remark42] (Open source, Golang, Easy to run docker)
> *   [Commento] (Open Source, available as a service, local install, or docker image)
> *   [Hyvor Talk] (Available as a service)

有使用github isses作为载体的，但看到网上有人反映数量会爆

Isso 倒也是自服的，但python写的，对比[remark42]还是会大一些，安装也会麻烦

这里选择的[remark42]，考虑到本身是[golang]编写，这样会有比较小的体积以及较好的性能

## 安装
官方的安装指引有使用[docker]和二进制安装两种方案

因为我的服务器资源有限，其实docker都是挺重的负担，这里选择直接安装二进制文件，编写服务脚本

从release的页面 https://github.com/umputun/remark42/releases 选择一个稳定的版本，一般就是linux 64位的版本
https://github.com/umputun/remark42/releases/download/v1.6.0/remark42.linux-amd64.tar.gz
```
   $ wget https://github.com/umputun/remark42/releases/download/v1.6.0/remark42.linux-amd64.tar.gz
   $ tar xzvf  remark42.linux-amd64.tar.gz
   $ sudo cp remark42.linux-amd64 /usr/local/bin/remark42  
```

因为是[golang]的程序，下载包只有不到8M的体积，而且没有其他依赖，在微型服务器上安装非常舒服

## 配置

### 创建用户/资源
```
$ sudo useradd -r remark42
$ sudo mkdir -m 770 /var/www/remark42
$ sudo chown :remark42 /var/www/remark42
```

### 运行参数（环境变量）
```
$ sudo mkdir /etc/remark42
$ sudo vim /etc/remark42/remark42.conf
REMARK_URL=https://myblog.address
SECRET=some_secret_key_phrase_1234
SITE=myblog
AUTH_ANON=true
EMOJI=true
```

### systemd 服务脚本
```
$ sudo vim /etc/systemd/system/remark42.service
[Unit]
Description=remark42 comment engine
After=network.target

[Service]
User=remark42
Group=remark42
EnvironmentFile=/etc/remark42/remark42.conf
WorkingDirectory=/var/www/remark42
Restart=always
RestartSec=5
ExecStart=/usr/local/bin/remark42 server

[Install]
WantedBy=multi-user.target

$ sudo systemctl daemon-reload
$ sudo systemctl start remark42
$ sudo systemctl enable remark42
```

### 配置反向代理(nginx)
最好设置一个独立的子域名，比如 remark.my.blog
```
$ sudo cat /etc/nginx/sites-available/remark42 
server {
    server_name remark.windy.me;
    listen 443;
    ssl_certificate /etc/letsencrypt/live/remark.my.blog/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/remark.my.blog/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot

    location / {
         proxy_redirect          off;
         proxy_set_header        X-Real-IP $remote_addr;
         proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
         proxy_set_header        Host $http_host;
         proxy_pass              http://127.0.0.1:8080/;
    }
}
```
[remark42]服务启动后，在本地监听8080端口，把nginx代理到服务上

### OAuth用户认证服务

#### Google
* 打开 https://console.developers.google.com/cloud-resource-manager
* 创建应用 remark
* 点击左上角下拉菜单，选择 APIs & Services ， 再点击 Credentials
* 在 Authorized JavaScript origins -> URIs 中添加blog的地址和remark服务的地址
* Authorized redirect URIs -> URIs 中填写回掉地址 https://remark.my.blog/auth/google/callback
* 根据页面信息填写配置文件 remark42.conf 中相应的配置信息AUTH_GOOGLE_CID，AUTH_GOOGLE_CSEC

#### Github
* 打开开发者页面 https://github.com/settings/developers
* 填写 Homepage URL "https://remark.my.blog"
* 填写 Authorization callback URL "https://remark.my.blog/auth/github/callback"
* 根据页面 Client ID, Client Secret 更新配置文件 remark42.conf:  AUTH_GITHUB_CID， AUTH_GITHUB_CSEC

#### Twitter
* 打开 https://developer.twitter.com/en/apps
* 创建 App
* 填写 Website URL "https://remark.my.blog"
* 填写 Callback URL "https://remark.my.blog/auth/twitter/callback"
* 点击 Keys and tokens 的tab, 查看 Consumer API keys： API key，API secret key
* 更新配置文件 remark42.conf， 填写 AUTH_TWITTER_CID ，AUTH_TWITTER_CSEC

### 配置hugo的评论模版
打开主题中的模版文件 layouts/partials/comments.html
添加remark42配置
```
{{- if  .Site.Params.remark42SiteID  }}
<script>
	var remark_config = {
		host: {{ .Site.Params.remark42Url }},
        site_id: {{ .Site.Params.remark42SiteID }},
        components: ['embed'],
		url: {{ .Permalink }},
        locale: {{ .Site.Language.Lang }},
        max_shown_comments: 10,
        theme: 'dark',
	  };
	  (function(c) {
		for(var i = 0; i < c.length; i++){
		  var d = document, s = d.createElement('script');
		  s.src = remark_config.host + '/web/' +c[i] +'.js';
		  s.defer = true;
		  (d.head || d.body).appendChild(s);
		}
	  })(remark_config.components || ['embed']);
   </script>
<div id="remark42" ></div>
{{- end }}
```
修改hugo配置文件config.toml
```
[params]
  remark42SiteID = "myblog"
  remark42Url = "https://remark.my.blog"
  comments = true
```

### 配置评论管理员
在评论框在底部成功出现以后，使用Oauth服务登陆评论系统，登陆成功以后可以点击评论的nickname，可以看到当前用户编号
设置用户编号为评论管理员，可以设置多个管理员，用逗号分割
```
$ sudo vim /etc/remark42/remark42.conf
ADMIN_SHARED_ID=github_20924f5ace2e27ff9b98801b837b8a495308d782
```

### 配置 telegram 的通知
* 打开 Telegram 应用
* 查询联系人 BotFather
* 和 BotFather 对话，输入 /newbot 创建机器人
* 根据提示信息，还需要创建一个结尾是 _bot的机器人
* 根据 HTTP API的token信息填写 remark42.conf 中 NOTIFY_TELEGRAM_TOKEN
```
$ sudo vim /etc/remark42/remark42.conf
NOTIFY_TYPE=telegram
NOTIFY_TELEGRAM_TOKEN=12345678:xy778Iltzsdr45tg
```
* 使用Telegram的应用，创建一个私有的Channel， 并把新创建的机器人加为Channel管理员
* 使用getUpdates的api获取channel的id
    * 访问API，https://api.telegram.org/botXXX:YYYY/getUpdates
    * 其中 XXX:YYYY 是前面生成的token 12345678:xy778Iltzsdr45tg
    * 如果能正确返回json，检查chat.id就是需要查询的id
    * 直接把id填写入NOTIFY_TELEGRAM_CHAN
    ```
    $ sudo vim /etc/remark42/remark42.conf
    NOTIFY_TELEGRAM_CHAN=1055587116
    ```

全部配置完后，重启remark42的服务
```
sudo systemctl restart remark42
```

## 参考资料
* [hugo comments] https://gohugo.io/content-management/comments/
* [remark42 official doc] https://github.com/umputun/remark42
* [hugo comments with remark42] https://blog.lasall.dev/post/hugo-and-comments-with-remark42/
* [get telegram channel id] https://www.reddit.com/r/Telegram/comments/8hpnje/q_how_to_get_channel_id_or_channelusername/


[comments]: https://gohugo.io/content-management/comments/ "comments"
[remark42]: https://github.com/umputun/remark42 "remark42"
[docker]: https://www.docker.com/ "docker"
[disqus]: https://disqus.com/ "disqus"
[golang]: https://golang.org/ "golang"
[staticman]: https://staticman.net/ "Staticman"
[talkyard]: https://www.talkyard.io/blog-comments "talkyard"
[intensedebate]: https://intensedebate.com/ "Intense Debate"
[graphcomment]: https://graphcomment.com/ "Graph Comment"
[muut]: https://muut.com/ "muut"
[isso]: https://posativ.org/isso/ "isso"
[Utterances]: https://utteranc.es/ "Utterances"
[Commento]: https://commento.io/ "commento"
[Hyvor Talk]: https://talk.hyvor.com/ "Hyvor Talk"
[Telegram 网页]: https://web.telegram.org/ "Telegram 网页"