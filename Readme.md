https://blog.03k.org/post/flytrap.html  

Flytrap，一个简单的蜜罐防火墙脚本。如其名字，就像一个捕蝇草，抓住来扫端口的IP地址捣蛋鬼，拉黑他DROP掉！  

脚本配置项：  

```shell
#Customizable option area
# 公网接口名字
wan_name="pppoe-wan"
# 定义扫了哪些端口就抓住他
trap_ports="21,22,23,3389"
# 定义是否也部署IPv6，yes/no
trap6="no"
# IP封禁时间，0为一直封禁，值大于0超时从名单中移除（单位：秒）
unlock="0"
#Customizable option end
```
改好脚本直接执行`sh flytrap.sh`就可以帮你加上规则。加入开机运行一次即可。  
脚本还有提供了其他操作命令：  

```shell
# 列出收集到的坏蛋IP
sh flytrap.sh list
# 列出收集到的坏蛋IP(v6)
sh flytrap.sh list 6
# 手动添加坏蛋IP地址
sh flytrap.sh add xxxxx
# 手动删除坏蛋IP地址
sh flytrap.sh del xxxxx
# 删除所有坏蛋IP地址
sh flytrap.sh delall
# 清空flytrap相关的iptables规则和所有IP地址集合
sh flytrap.sh clean
```
如果需要修改端口`trap_ports`，修改完了直接执行即可，会自动清除旧规则。  
如果要指定端口范围可以用冒号，比如`trap_ports="1:1024,3306,3389"`  
如果需要修改接口名`wan_name`，修改前可以执行`sh flytrap.sh clean`清除相关接口的规则。  
建议设置一些`unlock`选项的时间，存太多旧数据意义不大。  
脚本仅需依赖ipset和iptables命令。一些系统可能自带的防火墙命令是nft，由于nft并不像iptables那样有默认的表，可以根据提供的脚本和思路，按需修改。   

#### 注意事项
一些远程rdp客户端似乎会默认主动尝试3389端口导致把自己锁外面了，如果你有用到rdp的话，建议3389不要加到里面，rdp使用较高位端口，比如12388，并且把相邻的端口加入到陷阱（比如12387和12389）。