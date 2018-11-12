#!/bin/bash

###docker-ce install###
echo ""
echo "DOCKER INSTALLING................................"
apt update
apt install --assume-yes apt-transport-https ca-certificates curl software-properties-common
mv /etc/apt/sources.list /etc/apt/sources.list.old
cat <<EOF >>/etc/apt/sources.list
deb http://archive.ubuntu.com/ubuntu bionic main universe
deb http://archive.ubuntu.com/ubuntu bionic-security main universe
deb http://archive.ubuntu.com/ubuntu bionic-updates main universe
EOF
#curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
#apt-key fingerprint 0EBFCD88
#add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
apt update
apt install -y docker.io=17.12.1-0ubuntu1 
apt install nodejs npm -y
npm install npm --global
echo ""
echo "DOCKER DONE................................"

###Ansible install###
echo ""
echo "ANSIBLE INSTALLING................................"
echo ""
apt-add-repository ppa:ansible/ansible
apt update
apt install ansible -y
echo ""
echo "ANSIBLE DONE................................"

###K8s install###
echo ""
echo "KUBERNETES INSTALLING................................"
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >>/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update
apt-get --assume-yes install kubelet kubeadm kubectl
echo ""
echo "KUBERNETES DONE................................"
#apt-mark hold kubelet kubeadm kubectl
##Turnoff swap##
echo ""
echo "TURN OFF SWAP................................"
swapoff -a
sed -i '/swap/d' /etc/fstab
##provide pod-network is needed##
echo ""
echo "KUBERNETES INIT................................"
sysctl net.bridge.bridge-nf-call-iptables=1
kubeadm init --pod-network-cidr 10.10.10.0/24 
echo ""
echo "KUBERNETES INIT DONE................................"
##after init##
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
##Install pod-network kube-router##
echo ""
echo "KUBE-ROUTER INSTALLING................................"
KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f https://raw.githubusercontent.com/cloudnativelabs/kube-router/master/daemonset/kubeadm-kuberouter.yaml 
echo ""
echo "KUBE-ROUTER DONE................................"
##allow master run pod -> make tiller-deploy ready##
kubectl taint nodes --all node-role.kubernetes.io/master-
echo ""
echo "TAINT NODE DONE................................"

###Helm install###
echo ""
echo "HELM INSTALLING................................"
wget https://storage.googleapis.com/kubernetes-helm/helm-v2.11.0-linux-amd64.tar.gz >/root/
tar -zxvf /root/helm-v2.11.0-linux-amd64.tar.gz
mv linux-amd64/helm /usr/local/bin/helm
rm -rf /root/helm-v2.11.0-linux-amd64.tar.gz /root/linux-amd64/helm
#curl https://raw.githubusercontent.com/helm/helm/master/scripts/get > /root/get_helm.sh
#chmod 700 /root/get_helm.sh
#bash /root/get_helm.sh
helm init
##Upgrade helm##
kubectl create -f /root/kubernetes/awx/rbac-config.yaml
helm init --service-account tiller --upgrade
##set storage class "standard" to default storage class##
kubectl create -f /root/kubernetes/awx/sc-pv.yaml
kubectl patch storageclass standard -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
echo ""
echo "HELM DONE................................"

###AWX install###
cp -r /root/kubernetes/awx/ansible /root/ansible
chmod 755 -R /root/ansible
mkdir /root/projects
chmod 755 -R /root/projects

##sed -i "s/stable\/\postgresql/stable\/\postgresql --set persistence.enabled=false/g" /root/awx/installer/roles/kubernetes/tasks/main.yml
##plus modify volumes /etc/ansible and /var/libe/awx/projects mount to awx-web and awx-celery in awx/installer/roles/kubernetes/templates/deployment.yml.j2

#cd /root/kubernetes/awx/installer/
#ansible-playbook -i inventory install.yml