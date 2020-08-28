# kubeadm-install

Repository with simple scripts to install docker and kubernetes on various node types, and prepare for kubadm.

# TL;DR

```sh
curl https://raw.githubusercontent.com/deitch/kubeadm-install/master/install.sh | sh -s <runtime> <mode> [<advertise address>] [bootstrap] [caCert]
```

where:

* `runtime` - is the container runtime to use, currently supports: `docker`
* `mode` - is the installation mode to use, currently supports: `init` (initial control plane nodes), `join` (additional control plane nodes), `worker`
* `advertise address` - IP:port to use as the advertise address, relevant only on initial control plane node
* `bootstrap` - bootstrap information, relevant only in `join` and `worker` modes, formatted as `<IP>:<port>:<token>`, e.g. `147.75.78.157:6443:36ah6j.nv8myy52hpyy5gso`
* `caCert` - ca certificate hashes, comma-separated, relevant only in `join` and `worker` modes, e.g. `sha256:c9f1621ec77ed9053cd4a76f85d609791b20fab337537df309d3d8f6ac340732`

Valid formats:

```console
# initialize control plane, just requires advertise address
curl https://raw.githubusercontent.com/deitch/kubeadm-install/master/install.sh | sh -s docker init 100.100.50.10:6443

# join control plane, requires advertise address, control plane address and token, and ca cert hashes
curl https://raw.githubusercontent.com/deitch/kubeadm-install/master/install.sh | sh -s docker join 100.100.50.10:6443:36ah6j.nv8myy52hpyy5gso sha256:c9f1621ec77ed9053cd4a76f85d609791b20fab337537df309d3d8f6ac340732

# join worker, requires control plane address and token, and ca cert hashes
curl https://raw.githubusercontent.com/deitch/kubeadm-install/master/install.sh | sh -s docker worker 100.100.50.10:6443:36ah6j.nv8myy52hpyy5gso sha256:c9f1621ec77ed9053cd4a76f85d609791b20fab337537df309d3d8f6ac340732
```

It figures out your OS, if it is supported. Currently supports Ubuntu-16.04, Ubuntu-18.04, Ubuntu-20.04.

## Install

The basic install figures out your OS and your requested runtime, and installs all of the various dependencies, so you can then just run `kubeadm init` or `kubeadm join`.

## Configuration

The install also configures your `kubeadm.yaml` so that your `kubeadm init` or `kubeadm join` just works.

The configuration files are in `/etc/kubernetes/kubeadm.yaml`

To get the token and hashes for join and worker modes, go to the initial control plane mode and run:

```
kubeadm token create --print-join-command
```

which contains:

* original join address
* token
* CA cert hashes

We will use this information to join every other node.
