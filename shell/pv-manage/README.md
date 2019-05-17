# 1. 介绍
`k8s_patch_pv.sh` 用于修改pv的回收策略
`k8s_unbound_pvc.sh` 用于解决pv和pvc的绑定关系，让pv变成Available的可分配状态（不清除数据）
`k8s_recycler_pv.sh` 用于清除pv内数据，让pv变成Available的可分配状态
`k8s_delete_pv.sh` 用于删除pv及ceph集群内rbd或者cephfs目录及用户

# 2. 依赖
`k8s_delete_pv.sh` 删除详情：
删除ceph rbd是ssh到ceph管理节点操作删除rbd；
删除cephfs是ssh到ceph管理节点操作删除cephfs目录及用户，前提是cephfs已经挂载至该ceph管理节点；
