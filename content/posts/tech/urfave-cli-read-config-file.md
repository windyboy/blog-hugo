---
title: "Urfave Cli 从配置文件读取参数"
date: 2021-06-28T16:59:45+08:00
draft: false
comments: true
images:
Categories: ["技术"]
tags: ["golang","urfave-cli","cli","config"]
---
## 概述
[urfavecli] 的使用文档中关于从外部资源文件读取参数的说明比较模糊，从[github]的issues中也看到用户提到这个问题并提了PR，但现在这个版本依然没有更新，其实只是需要更新一下文档。


## 问题

> There is a separate package altsrc that adds support for getting flag values from other file input sources.
>
> Currently supported input source formats:
> 
>    YAML
>    JSON
>    TOML
>
>In order to get values for a flag from an alternate input source the following code would be added to wrap an existing cli.Flag like below:
>
>  altsrc.NewIntFlag(&cli.IntFlag{Name: "test"})
>
>Initialization must also occur for these flags. Below is an example initializing getting data from a yaml file below.
>
>  command.Before = altsrc.InitInputSourceWithContext(command.Flags, NewYamlSourceFromFlagFunc("load"))
>
>The code above will use the "load" string as a flag name to get the file name of a yaml file from the cli.Context. It will then use that file name to initialize the yaml input source for any flags that are defined on that command. As a note the "load" flag used would also have to be defined on the command flags in order for this code snippet to work.
>
>Currently only YAML, JSON, and TOML files are supported but developers can add support for other input sources by implementing the altsrc.InputSourceContext for their given sources.
>
>Here is a more complete sample of a command using YAML support:


```java
package main

import (
  "fmt"
  "os"

  "github.com/urfave/cli/v2"
  "github.com/urfave/cli/v2/altsrc"
)

func main() {
  flags := []cli.Flag{
    altsrc.NewIntFlag(&cli.IntFlag{Name: "test"}),
    &cli.StringFlag{Name: "load"},
  }

  app := &cli.App{
    Action: func(c *cli.Context) error {
      fmt.Println("--test value.*default: 0")
      return nil
    },
    Before: altsrc.InitInputSourceWithContext(flags, altsrc.NewYamlSourceFromFlagFunc("load")),
    Flags: flags,
  }

  app.Run(os.Args)
}
```

这段代码的意思实际做了3件事实现读取配置文件。

1. 创建一个load的字符串参数，用于传递文件名的参数
2. 创建一个test的整形参数，用于保存从配置文件中读取的内容
3. 调用altsrc的读取功能装载
   
由于原版文档并没有提供运行的方式，以及参数的输出，开始读完不知道发生了什么
简而言之就是使用一个名字是load的参数，传入文件名，并在文件中读取名为test的参数

## 解决方法

### 加入运行的指令

```bash
go run main.go --load ./app.yml
```
从名为app.yml的文件中读取参数test

app.yml:
> test: 123

### 在运行的Action中加入参数test的输出

```java
package main

import (
  "fmt"
  "os"

  "github.com/urfave/cli/v2"
  "github.com/urfave/cli/v2/altsrc"
)

func main() {
  flags := []cli.Flag{
    altsrc.NewIntFlag(&cli.IntFlag{Name: "test"}),
    &cli.StringFlag{Name: "load"},
  }

  app := &cli.App{
    Action: func(c *cli.Context) error {
      fmt.Println("test: ", c.Int("test"))
      return nil
    },
    Before: altsrc.InitInputSourceWithContext(flags, altsrc.NewYamlSourceFromFlagFunc("load")),
    Flags: flags,
  }

  app.Run(os.Args)
}
```

原来的：
> fmt.Println("--test value.*default: 0")

替换为：
> fmt.Println("test: ", c.Int("test"))

### 配置文件取值覆盖

因为读取配置文件是发生在参数载入之前，所以可以通过在命令行上赋值覆盖在配置文件中的取值

```bash
go run main.go --test 1 --load ./app.yml
test:  1
```

## 参考资料
* [urfave/cli] : https://github.com/urfave/cli
* [issue 800] : https://github.com/urfave/cli/issues/800


[urfavecli]: https://github.com/urfave/cli "urfavecli"
[github]: https://github.com "github"
