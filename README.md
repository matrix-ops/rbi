# Redis Binarization Installers 
- 一键部署三主三从Redis Cluster，需要手工干预的只有配置IP和各节点之间的SSH免密登陆
- 目前只支持Redis 6.0.5，后续将支持所有支持Redis Cluster的版本

## 使用方法
- 各节点配置好ssh免密登陆之后，执行此脚本，根据脚本提示输入节点IP和最后确认创建集群时输入Yes即可
```shell
bash rbi.sh
```
