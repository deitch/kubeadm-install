# kubeadm-install

Repository with simple scripts to install docker and kubernetes on various node types. To install:

```sh
curl https://raw.githubusercontent.com/deitch/kubeadm-install/master/install.sh | sh -s <runtime>
```

where:

* `runtime` - is the container runtime to use, currently supports: `docker`

It figures out your OS, if it is supported. Currently supports Ubuntu-16.04, Ubuntu-18.04, Ubuntu-20.04.

You can pass extra kubelet args, if desired, as extra arguments after the `<runtime>`.

## Configuration Options

If you want to add extra configuration options, you need to create a a kubeadm config file. This shows
an example of how to do it.

### Control Plane Nodes

#### Initial Control Plane Node

On the first node, we set an external cloud provider, and a cluster version of 1.18.5, at `/etc/kubernetes/kubeadm.yaml`:

```yaml
apiVersion: kubeadm.k8s.io/v1beta2
kind: InitConfiguration
nodeRegistration:
  kubeletExtraArgs:
    cloud-provider: "external"
localAPIEndpoint:
  advertiseAddress: 147.75.74.233
  bindPort: 6443
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
```

Note that the `advertiseAddress` should be an accessible address to all of the control plane nodes you intend to create.

And init with:

```console
kubeadm init --config=/etc/kubernetes/kubeadm.yaml
```

On this node, we will be able to add tokens for future nodes by running:

```
kubeadm token create --print-join-command
```

which contains:

* original join address
* token
* CA cert hashes

We will use this information to join every other node.

#### Subsequent Control Plane Nodes

If we want to add any other control plane nodes, we create a config file `/etc/kubernetes/kubeadm.yaml` with the following information:

```yaml
apiVersion: kubeadm.k8s.io/v1beta2
kind: JoinConfiguration
nodeRegistration:
  kubeletExtraArgs:
    cloud-provider: "external"
discovery:
  bootstrapToken:
    apiServerEndpoint: 147.75.78.157:6443
    token: 36ah6j.nv8myy52hpyy5gso
    caCertHashes:
    - sha256:c9f1621ec77ed9053cd4a76f85d609791b20fab337537df309d3d8f6ac340732
controlPlane:
  localAPIEndpoint:
    advertiseAddress: 147.75.74.233
    bindPort: 6443
```

Note the following:

* the `advertiseAddress` and the `apiServerEndpoint` **must** match the original address
* the token **must** be the token provided by `--print-join-command` on the first node
* the caCertHashes **must** be the hash provided by `--print-join-command` on the first node

Then we can join with:

```console
kubeadm join --config=/etc/kubernetes/kubeadm.yaml
```

### Worker Nodes

Create the kubeadm yaml at `/etc/kubernetes/kubeadm.yaml`:

```yaml
apiVersion: kubeadm.k8s.io/v1beta2
kind: JoinConfiguration
nodeRegistration:
  kubeletExtraArgs:
    cloud-provider: "external"
discovery:
  bootstrapToken:
    apiServerEndpoint: 147.75.78.157:6443
    token: 1unewr.2v3o9j8p9v22d0xy
    caCertHashes:
    - sha256:c9f1621ec77ed9053cd4a76f85d609791b20fab337537df309d3d8f6ac340732
```

Note the following:

* the `apiServerEndpoint` **must** match the original address
* the token **must** be the token provided by `--print-join-command` on the first node
* the caCertHashes **must** be the hash provided by `--print-join-command` on the first node

And join with:

```console
kubeadm join --config=/etc/kubernetes/kubeadm.yaml
```
