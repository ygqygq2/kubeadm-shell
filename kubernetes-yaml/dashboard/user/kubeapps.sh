kubectl apply -f https://raw.githubusercontent.com/kubeapps/kubeapps/master/docs/user/manifests/kubeapps-applications-read.yaml
kubectl create -n dev rolebinding dev-user1-view \
  --clusterrole=kubeapps-applications-read \
  --serviceaccount dev:dev-user1


export KUBEAPPS_NAMESPACE=kubeapps
kubectl apply -n $KUBEAPPS_NAMESPACE -f https://raw.githubusercontent.com/kubeapps/kubeapps/master/docs/user/manifests/kubeapps-repositories-read.yaml
kubectl create -n dev rolebinding dev-user1-edit \
--clusterrole=edit \
--serviceaccount dev:dev-user1
kubectl create -n $KUBEAPPS_NAMESPACE rolebinding dev1-user1-kubeapps-repositories-read \
--role=kubeapps-repositories-read \
--serviceaccount dev:dev-user1

#token获取：

kubectl get -n dev secret $(kubectl get -n dev serviceaccount dev-user1 -o jsonpath='{.secrets[].name}') -o jsonpath='{.data.token}' | base64 --decode
