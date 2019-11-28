# kubeadm-install

Repository with simple scripts to install docker and kubernetes on various node types. To install:

```sh
curl https://github.com/deitch/kubeadm-install/install.sh | sh - <runtime>
```

where:

* `runtime` - is the container runtime to use, currently supports: `docker`

It figures out your OS, if it is supported. Currently supports Ubuntu-16.04.

