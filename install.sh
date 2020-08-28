#!/bin/sh

usage() {
  echo "Usage:" >&2
  echo "$0 <runtime> <mode> [<advertise address>] [bootstrap] [caCert]" >&2
  echo "where <runtime> is one of:">&2
  echo "$runtimes" >&2
  echo "where <mode> is one of:" >&2
  echo "$modes" >&2
  echo "where <advertise address> is the advertising address for init mode, e.g. 147.75.78.157:6443">&2
  echo "where <bootstrap> is the bootstrap information for join and worker modes, IP and port and token, e.g. 147.75.78.157:6443:36ah6j.nv8myy52hpyy5gso" >&2
  echo "where <caCert> is the CA cert hashes for join and worker modes, e.g. sha256:c9f1621ec77ed9053cd4a76f85d609791b20fab337537df309d3d8f6ac340732" >&2
}


deploy_ubuntu_16_04_docker(){
  deploy_ubuntu_multiple_docker "$(lsb_release -cs)" xenial
}
deploy_ubuntu_18_04_docker(){
  deploy_ubuntu_multiple_docker "$(lsb_release -cs)" xenial
}
deploy_ubuntu_20_04_docker(){
  deploy_ubuntu_multiple_docker "$(lsb_release -cs)" xenial
}
deploy_ubuntu_multiple_docker(){
  local dockername="$1"
  local kubernetesname="$2"
  # turn off swap
  swapoff -a

  # install docker
  apt-get update -y
  apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  apt-key fingerprint 0EBFCD88
  add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $dockername stable"
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io

  # install kubeadm
  apt-get update -y
  apt-get install -y apt-transport-https curl
  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
  cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-${kubernetesname} main
EOF
  apt-get update -y
  apt-get install -y kubelet kubeadm kubectl
  apt-mark hold kubelet kubeadm kubectl
}

generate_kubeadm_config(){
  local mode="$1"
  local configpath="$2"
  local advertise
  local bootstrap
  local certs
  case $mode in
    "init")
      advertise="$3"
cat > $configpath <<EOF
apiVersion: kubeadm.k8s.io/v1beta2
kind: InitConfiguration
nodeRegistration:
  kubeletExtraArgs:
    cloud-provider: "external"
localAPIEndpoint:
  advertiseAddress: ${advertise%%:*}
  bindPort: ${advertise##*:}
---
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
kubernetesVersion: v1.18.5
apiServer:
  extraArgs:
    cloud-provider: "external"
controllerManager:
  extraArgs:
    cloud-provider: "external"
EOF
      ;;
    "join")
      bootstrap="$3"
      certs="$4"
      advertise=${bootstrap%:*}
cat > $configpath <<EOF
apiVersion: kubeadm.k8s.io/v1beta2
kind: JoinConfiguration
nodeRegistration:
  kubeletExtraArgs:
    cloud-provider: "external"
discovery:
  bootstrapToken:
    apiServerEndpoint: ${bootstrap%:*}
    token: ${bootstrap##*:}
    caCertHashes:
    - ${certs}
controlPlane:
  localAPIEndpoint:
    advertiseAddress: ${advertise%%:*}
    bindPort: ${advertise##*:}
EOF
      ;;
    "join")
      bootstrap="$3"
      certs="$4"
cat > $configpath <<EOF
apiVersion: kubeadm.k8s.io/v1beta2
kind: JoinConfiguration
nodeRegistration:
  kubeletExtraArgs:
    cloud-provider: "external"
discovery:
  bootstrapToken:
    apiServerEndpoint: ${bootstrap%:*}
    token: ${bootstrap##*:}
    caCertHashes:
    - ${certs}
EOF
      ;;
  esac
}

# supported runtimes
runtimes="docker"
# supported modes
modes="init join worker"
osfile="/etc/os-release"
kubeadmyaml="/etc/kubernetes/kubeadm.yaml"

# find my OS
if [ ! -f $osfile ]; then
  echo "cannot open $osfile for reading to determine if on supported OS" >&2
  exit 1
fi

osname=$(awk -F= '$1 == "NAME" {print $2}' $osfile | tr -d '"' | tr 'A-Z' 'a-z')
osrelease=$(awk -F= '$1 == "VERSION_ID" {print $2}' $osfile | tr -d '"' | tr '.' '_')

osfull=${osname}_${osrelease}

runtime=$1
mode=$2

if [ "$runtime" = "" ]; then
  usage
  exit 1
fi

found=$(echo $runtimes | grep -w $runtime 2>/dev/null)
if [ -z "$found" ]; then
  echo "unsupported runtime $runtime" >&2
  exit 1
fi

if [ "$mode" = "" ]; then
  usage
  exit 1
fi

found=$(echo $modes | grep -w $mode 2>/dev/null)
if [ -z "$found" ]; then
  echo "unsupported mode $mode" >&2
  exit 1
fi

funcname="deploy_${osfull}_${runtime}"
if command -V "${funcname}" >/dev/null 2>&1; then
  ${funcname}
else
  echo "unsupported combination of os/runtime ${osfull} ${runtime}" >&2
  exit 1
fi

# save the args for the rest
shift
shift

# generate the correct kubeadm config
generate_kubeadm_config $mode $kubeadmyaml $@

case $mode in
  "init")
     kubeadm init --config=$kubeadmyaml
     echo "Done. Don't forget to install your CNI networking."
     echo
     echo "To get the bootstrap information and CA cert hashes for another node, run:"
     echo "   kubeadm token create --print-join-command"
     echo
     echo "Here is initial output"
     kubeadm token create --print-join-command
     ;;
  "join")
     kubeadm join --config=$kubeadmyaml
     echo "Done."
     echo
     ;;
  "worker")
     kubeadm join --config=$kubeadmyaml
     ;;
esac


