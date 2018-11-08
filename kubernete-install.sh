#!/bin/bash

###docker-ce install###
echo -n "DOCKER INSTALLING................................"
apt update
apt install --assume-yes apt-transport-https ca-certificates curl software-properties-common
cat <<EOF >/etc/apt/sources.list
deb http://archive.ubuntu.com/ubuntu bionic main universe
deb http://archive.ubuntu.com/ubuntu bionic-security main universe
deb http://archive.ubuntu.com/ubuntu bionic-updates main universe
EOF
#curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
#apt-key fingerprint 0EBFCD88
#add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
apt update
apt install --assume-yes docker.io
echo -n "DOCKER DONE................................"
###Ansible install###
echo -n "ANSIBLE INSTALLING................................"
echo "deb http://ppa.launchpad.net/ansible/ansible/ubuntu trusty main" >> /etc/apt/sources.list
apt-get --assume-yes install dirmngr --install-recommends
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 93C4A3FD7BB9C367
add-apt-repository universe
apt update
apt install --assume-yes ansible
echo -n "ANSIBLE DONE................................"

###K8s install###
echo -n "KUBERNETES INSTALLING................................"

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update
apt-get --assume-yes install -y kubelet kubeadm kubectl
echo -n "KUBERNETES DONE................................"
#apt-mark hold kubelet kubeadm kubectl
##Turnoff swap##
echo -n "TURN OFF SWAP................................"
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab
##provide pod-network is needed##
echo -n "KUBERNETES INIT................................"
kubeadm init --pod-network-cidr 10.10.10.0/24 
echo -n "KUBERNETES INIT DONE................................"
##after init##
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
export KUBECONFIG=/etc/kubernetes/admin.conf
##Install pod-network kube-router##
echo -n "KUBE-ROUTER INSTALLING................................"
KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f https://raw.githubusercontent.com/cloudnativelabs/kube-router/master/daemonset/kubeadm-kuberouter.yaml 
echo -n "KUBE-ROUTER DONE................................"
##allow master run pod -> make tiller-deploy ready##
kubectl taint nodes --all node-role.kubernetes.io/master-
echo -n "TAINT NODE DONE................................"
#sleep 50

###Helm install###
echo -n "HELM INSTALLING................................"
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh
helm init
##Upgrade helm##
kubectl create -f /root/kubernetes/awx/rbac-config.yaml
helm init --service-account tiller --upgrade
##set storage class "standard" to default storage class##
kubectl create -f /root/kubernetes/awx/sc-pv.yaml
kubectl patch storageclass standard -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
echo -n "HELM DONE................................"
###AWX install###
cp -r /root/kubernetes/awx/ansible /root/ansible
chmod 755 -R /root/ansible
mkdir /root/projects
chmod 755 -R /root/projects
cd /root/kubernetes/awx/installer/

##sed -i "s/stable\/\postgresql/stable\/\postgresql --set persistence.enabled=false/g" /root/awx/installer/roles/kubernetes/tasks/main.yml
##plus modify volumes /etc/ansible and /var/libe/awx/projects mount to awx-web and awx-celery in awx/installer/roles/kubernetes/templates/deployment.yml.j2

ansible-playbook -i inventory install.yml