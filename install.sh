#!/bin/sh

set -e

usage() {
  echo "Usage:" >&2
  echo "$0 <mode> -r <runtime> -a <advertise address> [opts...]" >&2
  echo -n "where <mode> is one of: " >&2
  echo "$modes" >&2
  echo -n "where <runtime> is one of: ">&2
  echo "$runtimes" >&2
  echo "where <advertise address> is the advertising address for init mode, e.g. 147.75.78.157:6443">&2
  echo >&2
  echo "where" >&2
  echo "  -b <bootstrap> is the bootstrap token, e.g. 36ah6j.nv8myy52hpyy5gso" >&2
  echo "  -s <ca certs hash> is the CA cert hashes, e.g. sha256:c9f1621ec77ed9053cd4a76f85d609791b20fab337537df309d3d8f6ac340732" >&2
  echo "  -e <ca certs encryption key> is the CA cert keys, e.g. b98b6165eafb91dd690bb693a8e2f57f6043865fcf75da68abc251a7f3dba437" >&2
  echo "  -k <ca private key> is the CA private key, PEM format and base64 encoded; may also be provided in a PEM file" >&2
  echo "  -c <ca cert> is the CA certificate, PEM format and base64 encoded; may also be provided in a PEM file" >&2
  echo "  -i <ip> is the local address of the host to use for the API endpoint; defaults to whatever kubeadm discovers" >&2
  echo "  -o <os full> is the OS name and version to install for, e.g. ubuntu_16_04; defaults to discovery from /etc/os-release" >&2
  echo "  -d to set debug mode" >&2
  echo "  -h to show usage and exit" >&2
  exit 10
}

dryrun() {
  echo "DRYRUN: $1" >&2
}

deploy_ubuntu_16_04_docker(){
  deploy_ubuntu_multiple_docker_containerd "$(lsb_release -cs)" xenial "$1"
}
deploy_ubuntu_18_04_docker(){
  deploy_ubuntu_multiple_docker_containerd "$(lsb_release -cs)" xenial "$1"
}
deploy_ubuntu_20_04_docker(){
  deploy_ubuntu_multiple_docker_containerd "$(lsb_release -cs)" xenial "$1"
}
deploy_ubuntu_20_10_docker(){
  # replace focal (20.04) for groovy (20.10) since docker install only available for focal
  deploy_ubuntu_multiple_docker_containerd focal xenial "$1"
}
deploy_ubuntu_22_04_docker(){
  deploy_ubuntu_multiple_docker_containerd "$(lsb_release -cs)" xenial "$1"
}

deploy_ubuntu_16_04_containerd(){
  deploy_ubuntu_multiple_docker_containerd "$(lsb_release -cs)" xenial "$1"
}
deploy_ubuntu_18_04_containerd(){
  deploy_ubuntu_multiple_docker_containerd "$(lsb_release -cs)" xenial "$1"
}
deploy_ubuntu_20_04_containerd(){
  deploy_ubuntu_multiple_docker_containerd "$(lsb_release -cs)" xenial "$1"
}
deploy_ubuntu_20_10_containerd(){
  # replace focal (20.04) for groovy (20.10) since containerd install only available for focal
  deploy_ubuntu_multiple_docker_containerd focal xenial "$1"
}
deploy_ubuntu_22_04_containerd(){
  deploy_ubuntu_multiple_docker_containerd "$(lsb_release -cs)" xenial "$1"
}


deploy_ubuntu_multiple_docker_containerd(){
  local dockername="$1"
  local kubernetesname="$2"
  local version="$3"
  local aptversion="${version#v}-00"
  # turn off swap
  swapoff -a

  # install docker
  apt-get update -y
  apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  apt-key fingerprint 0EBFCD88
  add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $dockername stable"
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli

  # install containerd, which sometimes is containerd.io and sometimes containerd
  apt-get install -y containerd.io || apt-get install -y containerd || false

  # install kubeadm
  apt-get update -y
  apt-get install -y apt-transport-https curl
  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
  cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-${kubernetesname} main
EOF
  apt-get update -y
  apt-get install -y kubelet=${aptversion} kubeadm=${aptversion} kubectl=${aptversion}
  apt-mark hold kubelet kubeadm kubectl
}

deploy_amazon_linux_2_docker(){
  local version="$1"
  # turn off swap
  swapoff -a

  # install docker
  yum update -y
  yum install -y  ca-certificates curl tc
  yum install -y docker containerd

  # override the cgroup settings to be compatible with kubernetes
  # this really is NOT good, but no other choice for now
  mkdir -p /etc/systemd/system/docker.service.d
  cat <<EOF > /etc/systemd/system/docker.service.d/cgroupfs.conf
[Service]
EnvironmentFile=-/etc/systemd/system/docker.service.d/cgroups.sh
EOF
  cat <<EOF > /etc/systemd/system/docker.service.d/cgroups.sh
OPTIONS="--default-ulimit nofile=32768:65536 --exec-opt native.cgroupdriver=systemd"
EOF
  systemctl daemon-reload
  systemctl --now enable docker
  systemctl start docker

  # install kubeadm
  cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
  yum update -y
  yum install -y kubelet kubectl kubeadm
}

configure_runtime(){
  local runtime="$1"
  if [ "${runtime}" = "containerd" ]; then
    # remove potential disabled cri line
    containerd config default | grep -v '^\s*disabled_plugins.*"cri"' > /etc/containerd/config.toml
    systemctl restart containerd
  fi
}


# supported runtimes
runtimes="docker containerd"
# supported modes
modes="init join worker"
osfile="/etc/os-release"
kubeadmyaml="/etc/kubernetes/kubeadm.yaml"
version="v1.23.4"
curlinstall="curl https://raw.githubusercontent.com/deitch/kubeadm-install/master/install.sh"

mode="$1"
shift

dryrun=""
while getopts ":h?vdr:a:b:e:k:c:s:o:i:" opt; do
  case $opt in
    h|\?)
	usage
	;;
    v)
	set -x
	;;
    d)
	dryrun="true"
	;;
    r)
	runtime=$OPTARG
	;;
    a)
	advertise=$OPTARG
	;;
    b)
	bootstrap=$OPTARG
	;;
    e)
	certsKey=$OPTARG
	;;
    k)
	caKey=$OPTARG
	;;
    c)
	caCert=$OPTARG
	;;
    f)
	caKeyFile=$OPTARG
	;;
    g)
	caCertFile=$OPTARG
	;;
    s)
	certsha=$OPTARG
	;;
    o)
	osfull=$OPTARG
	;;
    i)
	localip=$OPTARG
	;;
  esac
done


if [ -z "$runtime" ]; then
  echo "runtime required" >&2
  usage
  exit 1
fi

found=$(echo $runtimes | grep -w $runtime 2>/dev/null)
if [ -z "$found" ]; then
  echo "unsupported runtime $runtime" >&2
  exit 1
fi

if [ "$mode" = "" ]; then
  echo "mode required" >&2
  usage
  exit 1
fi

found=$(echo $modes | grep -w $mode 2>/dev/null)
if [ -z "$found" ]; then
  echo "unsupported mode $mode" >&2
  exit 1
fi

# find my OS unless explicitly override
if [ -n "$osfull" ]; then
    echo "using osfull ${osfull}" >&2
else
    if [ ! -f $osfile ]; then
      echo "cannot open $osfile for reading to determine if on supported OS" >&2
      exit 1
    fi

    osname=$(awk -F= '$1 == "NAME" {print $2}' $osfile | tr -d '"' | tr 'A-Z' 'a-z' | tr ' ' '_')
    osrelease=$(awk -F= '$1 == "VERSION_ID" {print $2}' $osfile | tr -d '"' | tr '.' '_')

    osfull=${osname}_${osrelease}
fi

funcname="deploy_${osfull}_${runtime}"
if command -V "${funcname}" >/dev/null 2>&1; then
  if [ -n "$dryrun" ]; then
    dryrun "${funcname} ${version}"
  else 
    ${funcname} ${version}
  fi
else
  echo "unsupported combination of os/runtime ${osfull} ${runtime}" >&2
  exit 1
fi

crisock=""
case $runtime in
  "docker")
    crisock="/var/run/dockershim.sock"
    ;;
  "containerd")
    crisock="/run/containerd/containerd.sock"
    ;;
  "crio")
    crisock="/var/run/crio/crio.sock"
    ;;
esac

# any runtime-specific config
if [ -n "$dryrun" ]; then
   dryrun "configure_runtime ${runtime}"
else
  configure_runtime ${runtime}
fi

# reset BEFORE generating kubeconfig or any files
if [ -n "$dryrun" ]; then
   dryrun "kubeadm reset -f"
else
   kubeadm reset -f
fi

advertiseAddress=${advertise%%:*}
bindPort=${advertise##*:}

if [ -n "$dryrun" ]; then
  dryrun "$mode $advertise $bootstrap $certsha $certsKey"
  exit 0
fi

case $mode in
  "init")
      # the OS version determines whether or not we set the advertiseAddress as the master nodename
      # Amazon Linux uses it, others do not
      nameline=""
      case "$osfull" in
        amazon_linux*)
          nameline="  name: \"${advertiseAddress}\""
        ;;
      esac
      mkdir -p /etc/kubernetes/pki

      # if no certsKey provided, create a new one
      if [ -z "$certsKey" ]; then
          certsKey=$(kubeadm certs certificate-key)
      fi

      # kubeadm automatically will create the CA key and cert if ca.key and ca.crt are empty;
      # If only one is provided, kubeadm will error out. So we need do nothing except populate
      # whatever we were passed.

      if [ -n "$caKey" ]; then
        echo -n "$caKey" | base64 -d > /etc/kubernetes/pki/ca.key
      fi
      if [ -n "$caCert" ]; then
        echo -n "$caCert" | base64 -d > /etc/kubernetes/pki/ca.crt
      fi
      if [ -n "$caKeyFile" -a "$caKeyFile" != /etc/kubernetes/pki/ca.key ]; then
        cp $caKeyFile /etc/kubernetes/pki/ca.key
      fi
      if [ -n "$caCertFile" -a "$caCertFile" != /etc/kubernetes/pki/ca.crt ]; then
        cp $caCertFile /etc/kubernetes/pki/ca.crt
      fi

cat > $kubeadmyaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta2
kind: InitConfiguration
nodeRegistration:
  ${nameline}
  criSocket: "$crisock"
  kubeletExtraArgs:
    cloud-provider: "external"
localAPIEndpoint:
  advertiseAddress: ${localip}
  bindPort: ${bindPort}
certificateKey: ${certsKey}
---
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
kubernetesVersion: ${version}
controlPlaneEndpoint: ${advertiseAddress}:${bindPort}
apiServer:
  extraArgs:
    cloud-provider: "external"
controllerManager:
  extraArgs:
    cloud-provider: "external"
EOF
     # do we need to add the advertiseAddress to our local host?
     ping -c 3 -q ${advertiseAddress} && echo OK || ip addr add ${advertiseAddress}/32 dev lo
     kubeadm init --config=$kubeadmyaml --upload-certs
     echo "Done. Don't forget to install your CNI networking."
     echo
     echo "To get the bootstrap information and CA cert hashes for another node, run:"
     echo "   kubeadm token create --print-join-command"
     echo
     echo "Here are join commands:"
     joincmd=$(kubeadm token create --print-join-command "$bootstrap")
     if [ -z "$bootstrap" ]; then
         bootstrap=$(echo ${joincmd} | awk '{print $5}')
     fi
     certsha=$(echo ${joincmd} | awk '{print $7}')
     echo "control plane: ${curlinstall} "'|'" sh -s join -r ${runtime} -a ${advertise} -b ${bootstrap} -s ${certsha} -e ${certsKey}"
     echo "worker       : ${curlinstall} "'|'" sh -s worker -r ${runtime} -a ${advertise} -b ${bootstrap} -s ${certsha}"

     ;;
  "join")
      if [ -z "$bootstrap" ]; then
        echo "mode join had no valid bootstrap token" >&2
        usage
      fi
      if [ -z "$certsha" ]; then
        echo "mode join had no valid CA certs shas" >&2
        usage
      fi
      if [ -z "$certsKey" ]; then
        echo "mode join had no valid certs encryption key" >&2
        usage
      fi
cat > $kubeadmyaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta2
kind: JoinConfiguration
nodeRegistration:
  criSocket: "$crisock"
  kubeletExtraArgs:
    cloud-provider: "external"
discovery:
  bootstrapToken:
    apiServerEndpoint: ${advertise}
    token: ${bootstrap}
    caCertHashes:
    - ${certsha}
controlPlane:
  localAPIEndpoint:
    advertiseAddress: ${localip}
    bindPort: ${bindPort}
  certificateKey: ${certsKey}
EOF
     kubeadm join --config=$kubeadmyaml
     echo "Done."
     echo
     ;;
  "worker")
      if [ -z "$bootstrap" ]; then
        echo "mode worker had no valid bootstrap token" >&2
        usage
      fi
      if [ -z "$certsha" ]; then
        echo "mode worker had no valid certs address" >&2
        usage
      fi
cat > $kubeadmyaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta2
kind: JoinConfiguration
nodeRegistration:
  criSocket: "$crisock"
  kubeletExtraArgs:
    cloud-provider: "external"
discovery:
  bootstrapToken:
    apiServerEndpoint: ${advertise}
    token: ${bootstrap}
    caCertHashes:
    - ${certsha}
EOF
     kubeadm join --config=$kubeadmyaml
     ;;
esac

