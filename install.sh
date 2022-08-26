#!/bin/sh

set -e

usage() {
  echo "Usage:" >&2
  echo "$0 <runtime> <mode> [<advertise address>] [bootstrap] [caCert] [certKeys]" >&2
  echo "where <runtime> is one of:">&2
  echo "$runtimes" >&2
  echo "where <mode> is one of:" >&2
  echo "$modes" >&2
  echo "where <advertise address> is the advertising address for init mode, e.g. 147.75.78.157:6443">&2
  echo "where <bootstrap> is the bootstrap token, e.g. 36ah6j.nv8myy52hpyy5gso" >&2
  echo "where <caCert> is the CA cert hashes, e.g. sha256:c9f1621ec77ed9053cd4a76f85d609791b20fab337537df309d3d8f6ac340732" >&2
  echo "where <certKeys> is the CA cert keys, used only for \`init\` and \`join\` modes, e.g. b98b6165eafb91dd690bb693a8e2f57f6043865fcf75da68abc251a7f3dba437" >&2
  exit 10
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
  apt-get install -y docker-ce docker-ce-cli containerd.io

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

generate_kubeadm_config(){
  local mode="$1"
  local configpath="$2"
  local version="$3"
  local runtime="$4"
  local osfull="$5"
  local advertise="$6"
  local bootstrap="$7"
  local certs="$8"
  local certsKey="$9"
  if [ -z "$advertise" ]; then
    echo "no valid advertise address" >&2
    usage
  fi
  local crisock

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

  case $mode in
    "init")
      advertiseAddress=${advertise%%:*}
      bindPort=${advertise##*:}

      # the OS version determines whether or not we set the advertiseAddress as the master nodename
      # Amazon Linux uses it, others do not
      nameline=""
      case "$osfull" in
        amazon_linux*)
          nameline="  name: \"${advertiseAddress}\""
        ;;
      esac
      mkdir -p /etc/kubernetes/pki
      if [ -n "$certs" ]; then
        echo -n "$certs" | base64 -d > /etc/kubernetes/pki/ca.key
        # this needs CN and SAN
        #   - SubjectAlternateName: DNS:kubernetes
        #   - KeyUsage: Digital Signature, Key Encipherment, Certificate Sign
        #   - CN=kubernetes
        cat > /etc/kubernetes/pki/san.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions     = v3_req
x509_extensions    = v3_req

[req_distinguished_name]
commonName       = {{ common_name }}
emailAddress     = {{ ssl_certs_email }}
organizationName = {{ ssl_certs_organization }}
localityName     = {{ ssl_certs_locality }}
countryName      = {{ ssl_certs_country }}

[v3_req]
# The extentions to add to a self-signed cert
subjectKeyIdentifier = hash
basicConstraints     = critical,CA:true
subjectAltName       = DNS:kubernetes
keyUsage             = critical,digitalSignature,keyEncipherment,keyCertSign
EOF
        openssl req -new -x509 -nodes -days 365000 -key /etc/kubernetes/pki/ca.key -out /etc/kubernetes/pki/ca.crt -subj '/CN=kubernees' -config /etc/kubernetes/pki/san.cnf
        rm -f /etc/kubernetes/pki/san.cnf
      fi
cat > $configpath <<EOF
apiVersion: kubeadm.k8s.io/v1beta2
kind: InitConfiguration
nodeRegistration:
  ${nameline}
  criSocket: "$crisock"
  kubeletExtraArgs:
    cloud-provider: "external"
localAPIEndpoint:
  advertiseAddress: ${advertiseAddress}
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
      ;;
    "join")
      if [ -z "$bootstrap" ]; then
        echo "mode join had no valid bootstrap token" >&2
        usage
      fi
      if [ -z "$certs" ]; then
        echo "mode join had no valid certs address" >&2
        usage
      fi
      if [ -z "$certsKey" ]; then
        echo "mode join had no valid certs encryption key" >&2
        usage
      fi
cat > $configpath <<EOF
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
    - ${certs}
controlPlane:
  localAPIEndpoint:
    advertiseAddress: ${advertise%%:*}
    bindPort: ${advertise##*:}
  certificateKey: ${certsKey}
EOF
      ;;
    "worker")
      if [ -z "$bootstrap" ]; then
        echo "mode worker had no valid bootstrap token" >&2
        usage
      fi
      if [ -z "$certs" ]; then
        echo "mode worker had no valid certs address" >&2
        usage
      fi
cat > $configpath <<EOF
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
    - ${certs}
EOF
      ;;
  esac
}

# supported runtimes
runtimes="docker containerd"
# supported modes
modes="init join worker"
osfile="/etc/os-release"
kubeadmyaml="/etc/kubernetes/kubeadm.yaml"
version="v1.23.4"
curlinstall="curl https://raw.githubusercontent.com/deitch/kubeadm-install/master/install.sh"

# find my OS
if [ ! -f $osfile ]; then
  echo "cannot open $osfile for reading to determine if on supported OS" >&2
  exit 1
fi

osname=$(awk -F= '$1 == "NAME" {print $2}' $osfile | tr -d '"' | tr 'A-Z' 'a-z' | tr ' ' '_')
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
  ${funcname} ${version}
else
  echo "unsupported combination of os/runtime ${osfull} ${runtime}" >&2
  exit 1
fi

# save the args for the rest
shift
shift

# extract the advertise address, bootstrap token, caCerts
advertise="$1"
bootstrap="$2"
# certshas might be the private key or the shas, depending on mode
certshas="$3"
certsKey="$4"

shift
shift
shift
shift

# must either provide ALL OF: bootstrap certshas certsKey
# OR provide none
if [ -z "$bootstrap" -a -n "$certshas" ]; then
  usage
fi
if [ -n "$bootstrap" -a -z "$certshas" ]; then
  usage
fi
if [ -z "$bootstrap" -a -n "$certsKey" ]; then
  usage
fi
if [ -n "$bootstrap" -a -z "$certsKey" ]; then
  usage
fi
if [ -z "$certshas" -a -n "$certsKey" ]; then
  usage
fi
if [ -n "$certshas" -a -z "$certsKey" ]; then
  usage
fi

# if no certsKey provided, create a new one
if [ -z "$certsKey" -a "$mode" = "init" ]; then
    certsKey=$(kubeadm certs certificate-key)
fi

# any runtime-specific config
configure_runtime ${runtime}

# reset BEFORE generating kubeconfig or any files
kubeadm reset -f

# generate the correct kubeadm config
generate_kubeadm_config "$mode" "$kubeadmyaml" "$version" "$runtime" "$osfull" "$advertise" "$bootstrap" "$certshas" "$certsKey"


case $mode in
  "init")
     # do we need to add the advertiseAddress to our local host?
     advertiseAddress=${advertise%%:*}
     ping -c 3 -q ${advertiseAddress } && echo OK || ip addr add ${advertiseAddress}/32 dev lo
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
     certshas=$(echo ${joincmd} | awk '{print $7}')
     echo "control plane: ${curlinstall} "'|'" sh -s ${runtime} join ${advertise} ${bootstrap} ${certshas} ${certsKey}"
     echo "worker       : ${curlinstall} "'|'" sh -s ${runtime} worker ${advertise} ${bootstrap} ${certshas}"

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

