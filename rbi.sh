#!/bin/bash
#Redis Binarization Installer
echo "请在任意一台可以连接至目标Redis集群的服务器或Redis集群自身的节点上执行此脚本"
echo "请提前在各节点上实现ssh互信免密登录"
read -p "输入三个Redis Master节点IP,以空格分割:" -a MasterIP
read -p "输入三个Redis Slave节点IP,以空格分割:" -a SlaveIP
nodeCount=(${MasterIP[*]}  ${SlaveIP[*]})
if [ ! $(which redis-server) ];then
    echo "正在获取Redis二进制可执行文件...."
    yum install wget -y &>/dev/null &&  wget http://120.79.32.103:808/redis-bin-6.0.5.tar.gz -O /tmp/redis-bin-6.0.5.tar.gz && tar xvf /tmp/redis-bin-6.0.5.tar.gz -C /usr/local/bin/
fi
cat << EOF > /usr/local/etc/redis.conf
daemonize yes
port 6379
dir /var/lib/redis
cluster-enabled yes
cluster-config-file redis-cluster.conf
cluster-node-timeout 5000
bind 0.0.0.0
protected-mode no
save ""
appendonly no
requirepass payeco@Redis!Cluster
masterauth payeco@Redis!Cluster
logfile "/var/log/redis/redis.log"
EOF

cat << EOF > /tmp/iptables
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
-A INPUT -p icmp -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -p tcp -m state --state NEW -m tcp --dport 22 -j ACCEPT
-A INPUT -p tcp -m state --state NEW -m tcp --dport 6379 -j ACCEPT
-A INPUT -p tcp -m state --state NEW -m tcp --dport 6380 -j ACCEPT
-A INPUT -p tcp -m state --state NEW -m tcp --dport 16379 -j ACCEPT
-A INPUT -p tcp -m state --state NEW -m tcp --dport 26379 -j ACCEPT
-A INPUT -j REJECT --reject-with icmp-host-prohibited
-A FORWARD -j REJECT --reject-with icmp-host-prohibited
COMMIT
EOF

echo "正在配置iptables和SELinux"
sleep 3
for i in ${nodeCount[*]};do
    ssh $i "systemctl mask firewalld && sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config && setenforce 0 && yum install iptables-services -y &> /dev/null"
    scp /tmp/iptables $i:/etc/sysconfig/iptables
    ssh $i "systemctl restart iptables"
done

for i in ${nodeCount[*]};do
    ssh $i mkdir /var/log/redis /var/lib/redis -p  && yum install psmisc -y&>/dev/null
    scp /usr/local/bin/redis* $i:/usr/local/bin/
    scp /usr/local/etc/redis.conf $i:/usr/local/etc/redis.conf
    if [[ ! $(killall -0 redis-server) ]];then
        ssh $i "cd /var/lib/redis/ && nohup /usr/local/bin/redis-server /usr/local/etc/redis.conf &"
    fi
done

echo "即将创建Redis Cluster，确认信息无误后，输入yes并回车"
sleep 2
ssh ${MasterIP[0]} " 
redis-cli -a payeco@Redis\!Cluster --cluster create --cluster-replicas 1 ${nodeCount[0]}:6379 ${nodeCount[1]}:6379 ${nodeCount[2]}:6379 ${nodeCount[3]}:6379 ${nodeCount[4]}:6379 ${nodeCount[5]}:6379"
