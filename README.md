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
an example of how to do it:

On the first node, we set an external cloud provider, and a cluster version of 1.18.5, at `/etc/kubernetes/kubeadm.yaml`:

```yaml
apiVersion: kubeadm.k8s.io/v1beta2
kind: InitConfiguration
nodeRegistration:
  kubeletExtraArgs:
    cloud-provider: "external"
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

And init with:

```console
kubeadm init --config=/etc/kubernetes/kubeadm.yaml
```

On subsequent nodes, we take the output of `kubeadm token create --print-join-command` from the first node, which contains:

* original join address
* token
* CA cert hashes

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

And join with:

```console
kubeadm join --config=/etc/kubernetes/kubeadm.yaml
```
