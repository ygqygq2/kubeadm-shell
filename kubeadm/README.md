## 使用说明

1. 脚本Kubeadm安装Kubernetes（支持1或3台master）
2. 需要在节点提前手动设置hostname
3. 脚本初始化时添加ssh key登录其它节点，可能需要用户按提示输入ssh密码
4. 安装集群在第一台master节点上执行此脚本；
5. 添加节点在节点上执行此脚本。
6. 单master安装脚本设置:
  INSTALL_CLUSTER="true"    
  INSTALL_SLB="false"    
  k8s_master_vip="10.37.129.11"    
  server0="master1:10.37.129.11"    
  server1=""    
  server2=""    
