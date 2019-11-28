#!/bin/sh

usage() {
  echo "Usage:" >&2
  echo "$0 <runtime>" >&2
  echo "where <runtime> is one of:">&2
  echo "$runtimes" >&2
}

deploy_ubuntu_16_04_docker(){
  # turn off swap
  swapoff -a

  # install docker
  apt-get update -y
  apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  apt-key fingerprint 0EBFCD88
  add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

  # install kubeadm
  apt-get update -y
  apt-get install -y apt-transport-https curl
  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
  cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
  apt-get update -y
  apt-get install -y kubelet kubeadm kubectl
  apt-mark hold kubelet kubeadm kubectl
}

# supported runtimes
runtimes="docker"
osfile="/etc/os-release"

# find my OS
if [ ! -f $osfile ]; then
  echo "cannot open $osfile for reading to determine if on supported OS" >&2
  exit 1
fi

osname=$(awk -F= '$1 == "NAME" {print $2}' $osfile | tr -d '"' | tr 'A-Z' 'a-z')
osrelease=$(awk -F= '$1 == "VERSION_ID" {print $2}' $osfile | tr -d '"' | tr '.' '_')

osfull=${osname}_${osrelease}

runtime=$1

if [ "$runtime" = "" ]; then
  usage
  exit 1
fi
found=$(echo $runtimes | grep -w $runtime 2>/dev/null)
if [ -z "$found" ]; then
  echo "unsupported runtime $runtime" >&2
  exit 1
fi


funcname="deploy_${osfull}_${runtime}"
if command -V "${funcname}" >/dev/null 2>&1; then
  ${funcname}
else
  echo "unsupported combination of os/runtime ${osfull} ${runtime}" >&2
  exit 1
fi

# report how to start a control plane or join
echo "If starting a new cluster, run:"
echo "  kubeadm init"
echo
echo "Then install your networking"
echo
echo "If joining an existing cluster:"
echo "1. Go to the existing master and run:"
echo "  kubeadm token create --print-join-command"
echo "2. Copy the output of that command"
echo "3. Run the output on this node"



