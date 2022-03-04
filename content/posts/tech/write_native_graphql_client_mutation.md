---
title: "使用go的graphql本地客户端mutation"
date: 2021-07-12T11:14:40+08:00
draft: false
comments: true
images:
Categories: ["技术"]
tags: ["hasura","golang","graphql"]
---

## 概述

[hasura-go-client] 的文档中关于mutation部分的描述


> For example, to make the following GraphQL mutation:
```
mutation($ep: Episode!, $review: ReviewInput!) {
	createReview(episode: $ep, review: $review) {
		stars
		commentary
	}
}
variables {
	"ep": "JEDI",
	"review": {
		"stars": 5,
		"commentary": "This is a great movie!"
	}
}
```
> You can define:
```
var m struct {
	CreateReview struct {
		Stars      graphql.Int
		Commentary graphql.String
	} `graphql:"createReview(episode: $ep, review: $review)"`
}
variables := map[string]interface{}{
	"ep": starwars.Episode("JEDI"),
	"review": starwars.ReviewInput{
		Stars:      graphql.Int(5),
		Commentary: graphql.String("This is a great movie!"),
	},
}
```
当前的版本v0.2.0似乎有出入
如果模仿这里例子编写代码，并不能得到预期的效果。

大致上有两个问题：
1. 传入的struct名称应该是一个以input结尾的类型
2. 内部的变量必须大写首字母，又必须使用json的说明在转换的时候变成小写
   

## 正确的做法

首先在[hasura]的服务器上创建数据实体，如果创建的实体名为"data"，[hasura]服务器就会生成一些mutation的操作。
如果是插入一条数据，则需要调用"data_instert_one"的mutation。

graphql的对应操作为：
```graphql
mutation m($data: data_insert_input!) {
  insert_telegram_one(object: $data) {
    id
  }
}

{
  "data": {
    "text": "DDDEEDDSS"
  }
}
```
这里的例子是插入列名为"text"的数据，返回自动生成的id

对应的go程序应该是
```go
type data_insert_input struct {
	Text graphql.String `json:"text"`
}
client := graphql.NewClient(url, nil)

var mutation struct {
    InsertTelegramOne struct {
        Id graphql.ID
    } `graphql:"insert_data_one(object: $data)"`
}

variables := map[string]interface{}{
    "data": data_insert_input{
        Text: graphql.String(text),
    },
}
```
这里注意，调用的mutation的名字是"insert_data_one", 参数固定为"data_insert_input"都是固定的。
结构内部的变量名必须首字母大小，但必须在json转换的时候注解回小写名称（数据库中列名为小写）
在variables中定义的名称"data",则是对应调用中"$data"





[hasura-go-client]: https://github.com/hasura/go-graphql-client "hasura-go-client"
[hasura]: https://hasura.io
[graphql]: https://graphql.org
