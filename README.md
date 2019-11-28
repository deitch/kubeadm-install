# kubeadm-install

Repository with simple scripts to install docker and kubernetes on various node types. To install:

```sh
curl https://raw.githubusercontent.com/deitch/kubeadm-install/master/install.sh | sh -s <runtime>
```

where:

* `runtime` - is the container runtime to use, currently supports: `docker`

It figures out your OS, if it is supported. Currently supports Ubuntu-16.04.

