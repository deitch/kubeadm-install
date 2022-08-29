# kubeadm-install

Repository with simple scripts to install docker and containerd and kubernetes on various node types, and prepare for kubadm.

# TL;DR

```sh
curl https://raw.githubusercontent.com/deitch/kubeadm-install/master/install.sh | sh -s <runtime> <mode> <advertise address> [args...]
```

The args change depending on the mode.

```sh
curl https://raw.githubusercontent.com/deitch/kubeadm-install/master/install.sh | sh -s init -r <runtime> -a <advertise address> [-b <bootstrap> -e <certEncryptionKey> -k <caPrivateKey> -c <caCert>]
curl https://raw.githubusercontent.com/deitch/kubeadm-install/master/install.sh | sh -s join -r <runtime> -a <advertise address> -b <bootstrap> -s <caCertsHash> -e <certEncryptionKey>
curl https://raw.githubusercontent.com/deitch/kubeadm-install/master/install.sh | sh -s worker -r <runtime> -a <advertise address> -b <bootstrap> -s <caCertsHash>
```

where:

* `mode` - **all modes** installation mode to use, currently supports: `init` (initial control plane nodes), `join` (additional control plane nodes), `worker`. This is the only positional parameter, and **must** be provided first.
* `-r runtime` - **all modes** container runtime to use, currently supports: `docker`, `containerd`
* `-a <advertise address>` - **all modes** IP:port to use as the advertise address. For `init` mode, the address on which to listen; for `join` and `worker` modes, the address on which to reach the initial control plane node. e.g. `147.75.78.157:6443`
* `-b bootstrap` - **required for `join` and `worker`, optional for `init`** bootstrap token to use when additional control plane (`join`) or workers (`worker`) join; if not provided for `init`, will automatically generate, e.g. `36ah6j.nv8myy52hpyy5gso`
* `-e certEncryptionKey` - **required for `join`, optional for `init`, error for `worker`** CA certificate keys, usually generated via `kubeadm certs certificate-key`; if not provided for `init`, will automatically generate, e.g. `b98b6165eafb91dd690bb693a8e2f57f6043865fcf75da68abc251a7f3dba437`
* `-s caCertsHash` - **required for `join` and `worker`, error if provided to `init`** CA certificate hash, e.g. `sha256:c9f1621ec77ed9053cd4a76f85d609791b20fab337537df309d3d8f6ac340732`
* `-k caPrivateKey` - **optional for `init`, error for `join` or `worker`** base64-encoded 2048-bit RSA private key in PEM format; if not provided, will automatically generate
* `-c caCert` - **optional for `init`, error for `join` or `worker`** base64-encoded certificate for CA; must be provided if caPrivateKey provided

For the advertise address, the IP address must be reachable from all of the hosts, including the master, and must be consistent. We strongly
recommend that you use an IP that stays, like on Equinix Metal, or an Elastic IP.

For `caPrivateKey`, can be generated via:

```sh
openssl genrsa 2048
```

For `caCertsHash`, can be generated from a private key via:

```sh
echo "${caPrivateKey}" | openssl rsa -outform PEM -pubout 2>/dev/null | openssl rsa -pubin -outform DER 2>/dev/null | sha256sum | cut -d' ' -f1
```

Valid formats:

```console
# setup vars
ADVERTISE_ADDRESS=100.100.50.10:6443
BOOTSTRAP_TOKEN=36ah6j.nv8myy52hpyy5gso
CA_ENCRYPTION_KEYS=b98b6165eafb91dd690bb693a8e2f57f6043865fcf75da68abc251a7f3dba437
CA_PRIVATE_KEY_PEM_B64=LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlFcEFJQkFBS0NBUUVBK2x5MDNsWEUyOThIaGloS0ovZDBmN2N4dmt5WHZHNityQUVYeTQ1cjBreWl3UDE2CmgyQUNmWTVjN041bzA0U0wzYXNUU0xndkJsbVM2YWFFMkhnRGN0SXM5YWIycVAyNlpSWXVVRUdia3lYYVUyOEUKUTJkcEZ1bjQvaldUOXlMVU1JeVNIZHdqbm9KVFVTUE1OT21Bajc2OW52aU1KZzQveDFQY0EzYWRPbCtHaWhOQgpCNlBkNmtjWm9GcDJZWlNsZXhMMDM3R25XOHJvdWI2aERQZ0pxc2NyTWNxcVNVOURCVS9qckNML0RpaC8wRzFQCkd6MUM5ckxtTElnQXVkbFoyNUVzbjlOVlVHZHlxejZMQ3ZNaUVaa1l2S1BkaksxWDEwKytiMzRrdW4zeHRkaVQKeUkxUW5rY0JzVDJKZ3ozdTd6em9BQXRpby9kUFAvTWFlNzJ1R3dJREFRQUJBb0lCQVFDSy95ZEhmUFREWVVxTApHQms3b1MzanJqQ0d4MzFDbDNWeWgxVFBwVzJGSHhrSTduRzFjUDlROTlYdGgvbEkzWUROZTZwRUtFV3JUOVc1CnRNSnljQWJ5RzIvc25scTVMY3pyVEdwQUVueXVNRWpMSTRxSlpZTTV2b0tIbC9Wak1zbjlmajJ0S0VmNk83N0kKQUlqaUkzVkYyUTdya0hBMnZKaDZNTHVvakpUMEQzWEVxQ0RWTVUxSlUvM2ZURjZhWWNkYmxkTVNoUWY2QTBoOQo5L01DNERJUWJwNThWVWhKRkY5ZTQ2SFlnTHh0ekJ6ZFUyODVmSHBxU1VpdHNrdnBzN2doU1U3Tlg4REVzMlVFCjNtdWFLcjd4UVJoSHhPRFVWOGpNUVBDenptVTI3bjl3Z1ErWmhWNmt5NnYrOFJud1R6b25WU2V0RzU1U1ZKcFQKUEVkUGFVQWhBb0dCQVA0dTdiYXNOOFZOeUg1aVBHN21lYnF6OW5HR0t0ellSN3Zzemhxdm1Hckh5OUQ0b0pJRApIVTNVK3piVXFBTnFTUjYzeG1xRVYwdkNUTjFCSHpnVS94VkZYNE91M3MzSWc3aUM3djljeGd5TjJlNVk5by9xCmluNEZwUHRqMW9YMUZBNFhZZnp2d3g0N0p1Z2ljZ1dHdHlhc082Nkx6UGxjd0RNcFY2SkxHWGdyQW9HQkFQd20KeVZUODRWK2w1SHYraStxRUZsYXRZVU5RV2QwUzgyYUt5UVRENjNrVjV4TmRqR3g2RmtvaGh2dkU1UU9TcFJ4UgpUMFY3SGFKVktxNDJtOXdnVTk2MjMxeGJxZzNEMGVaM3JlTGc5ekJEMXZiVEQ0YmF2OXJ2L0lhb2tXYVovWU5ZCjQ1b3JzMkRib2l4aHB2VkMwRW9zMFlyVVBUU0FwSDNoaGtRL0V6blJBb0dCQUplRkxBazMwaXNZZWdyMHptZWgKbGpENHRGRHFGTVQvWEl1bTF4bkxVUVZlUXA0NGg2ZGltZVphcnNINXRJb01vcmZmL3pSaDNaUDRxRTlBVWJiaAp0VWxkeUZrOE5lN2Z0NzJXdDVlY0d5ZENyQVhNSEhhZjdweS9DcUVjMjdXUTZicVlyNzNTd3pKVE9wY29hV1huCjcyZnJSY3gvNDlsR05BQ0xoWVRtVmJGdkFvR0FDcUJ2MTc4WW1IbGJXY1p1aXlHcDkxa3pRaXordkl4eDZaNXIKdm1HcmFOejljaGw5TTQwcHAxSW1hREh5SE9adlF2UkNUUUZWVEdRZWVsMGUwSFlrVXJ5T1NVd3JySXpXS2NwZApiN1JmZG85RlhmMmpKK0hNT0NQcEZwdkFGUHprYkVhd3dPeWFrTGh3NjBIcVVXZlJjMjdVSGUrMzdLQ0hUaTdWCkE4ZE12aUVDZ1lCVUVuV1hVeVdPNE9WT01NdmMzY1VDanNNdmlBY2VDNmJFZUxJWmI3NWQyVk5lWkw1Skt2Nk0KVGs5RmluRTdBOVJ5Zk9GT20wZlZsZkozekZxRzBEdVZsUHp4aVQwTU1KQjc3N3VWTUZIb0dTVlQrV0IvUlJFQQpDVGFTTkZMd254SWovcmpwMnlpYm5kRzRjMytPU29KRVdISGR6cmVWVENtK2FIMnZDUG1wMVE9PQotLS0tLUVORCBSU0EgUFJJVkFURSBLRVktLS0tLQ==
CA_CERT_B64=LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURCakNDQWU2Z0F3SUJBZ0lKQU5EWExhWkdRbE5STUEwR0NTcUdTSWIzRFFFQkN3VUFNQlF4RWpBUUJnTlYKQkFNTUNXdDFZbVZ5Ym1WbGN6QWdGdzB5TWpBNE1qa3dPVFEyTURGYUdBOHpNREl4TVRJek1EQTVORFl3TVZvdwpGREVTTUJBR0ExVUVBd3dKYTNWaVpYSnVaV1Z6TUlJQklqQU5CZ2txaGtpRzl3MEJBUUVGQUFPQ0FROEFNSUlCCkNnS0NBUUVBemhuRXVPdGJyQ3hleWgxWk00Q240RVhuVzhERVQrNm5LV1hTVTVNU3k5R1VjSjRCWGgrQmlObnEKZTEvRERJdTlMb0MrRisyWVkrZU9xZC9takJVai9nSVNDUjVvMUN6bWpiWC9Yc2JybDJvclNNb3F3YndtVWJJNApVQzVwTjhXMU5SNkhpbWZMK01BRk90YkFLV0RpN3pPQ2pHeHdybzBsQ3dnN1hwRmlwSXVHaE5xcWM1WXB1UDgyCmdqQmRVWUh0MFV2OGZWUUo1U0gxZ29FUjQwUkZSa09UOUJJR2VJV0JWbmNnZk1jWGRUNlJ3TCtYOFlTbDB1MEIKS3RtN1grd0p6RXIyYmVGQVBDejdFc3Zqc0xHV1pWcUZLdkFWREpsYlhYNEdMbHhWS24vQ3EwRnZpVkowQm9ZbgpYVjhZYVhNRDFNUXJYY3RlQ1NuSXlvMXZFSWowY3dJREFRQUJvMWt3VnpBZEJnTlZIUTRFRmdRVVdHS0k4RitGCmYrZ2gyUEJOR0J2T0UyTGlqL293RHdZRFZSMFRBUUgvQkFVd0F3RUIvekFWQmdOVkhSRUVEakFNZ2dwcmRXSmwKY201bGRHVnpNQTRHQTFVZER3RUIvd1FFQXdJQ3BEQU5CZ2txaGtpRzl3MEJBUXNGQUFPQ0FRRUFidnY3bitNSwpocTFtVHc3MHNJU3BmUTdCbTlLaHNncHFrMVQxOFJQUHg5dU5xdGN0SmxYN1BJcHFHT3hFUUpDODNuaDRDcFFvCnRPUjRXd3d1bHUyM3ZqeTdQdFhjcHBOQkc0d0JjWUwrQndEQmM3T2FsL1NGbVR3N3N3QzVad2ZLMGd4SmFMNmYKam4wNkZMS1NjSTlpcDdoUWFnd1RaMVdWUUFEVGFtUFU1N0RFWEd0ZXdITjFJelNlVjlWY1h4eVJlTkZib0p2KwptcXlZUzA5V2dXc0g4emVzdFVwZVVJUnlOTmw0QllrczYxcFVWbDc4bmtjTUEydnRYeFgxc0UzQW9pbjU0cTNxCjkvelUranZjQTltdUlsZEZQaExnSVB5T1RwTmZRNnVzWUtFbktBUHh6S2NaYmg4a29qQkhGNFVCRVVnVHNmVlkKZ2NlS3NSbC9GR0MrZGc9PQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==
CA_CERT_HASH=sha256:c9f1621ec77ed9053cd4a76f85d609791b20fab337537df309d3d8f6ac340732

# OR
# create a new key and determine its cert hash
caPrivateKey=$(openssl genrsa 2048 2>/dev/null)
echo "$caPrivateKey" > /tmp/ca.key
CA_PRIVATE_KEY_PEM_B64=$(echo -n $"${caPrivateKey}" | base64 -w 0)
caPubKey=$(echo -n "${caPrivateKey}" | openssl rsa -outform PEM -pubout 2>/dev/null)
CA_CERT_HASH=$(echo -n "${caPubKey}" | openssl rsa -pubin -outform DER 2>/dev/null | sha256sum | cut -d' ' -f1)
openssl req -new -x509 -nodes -days 365000 -key /tmp/ca.key -out /tmp/ca.crt -subj '/CN=kubernees' -config /tmp/ca.cnf
CA_CERT_B64=$(cat /tmp/ca.crt | base64 -w 0)

# initialize control plane, just requires advertise address, generate CA key/cert, bootstrap token, encryption keys
curl https://raw.githubusercontent.com/deitch/kubeadm-install/master/install.sh | sh -s init -r containerd -a ${ADVERTISE_ADDRESS}

# initialize control plane, providing required advertise address, optional CA key/cert, bootstrap token, encryption keys
curl https://raw.githubusercontent.com/deitch/kubeadm-install/master/install.sh | sh -s init -r containerd -a ${ADVERTISE_ADDRESS} -b ${BOOTSTRAP_TOKEN} -e ${CA_ENCRYPTION_KEYS} -k ${CA_PRIVATE_KEY_PEM_B64} -c ${CA_CERT_B64}

# join control plane, requires advertise address, control plane address and token, and ca cert hashes
curl https://raw.githubusercontent.com/deitch/kubeadm-install/master/install.sh | sh -s join -r containerd -a ${ADVERTISE_ADDRESS} -b ${BOOTSTRAP_TOKEN} -s ${CA_CERT_HASH} -e ${CA_ENCRYPTION_KEYS}

# join worker, requires control plane address and token, and ca cert hashes
curl https://raw.githubusercontent.com/deitch/kubeadm-install/master/install.sh | sh -s worker -r containerd -a ${ADVERTISE_ADDRESS} -b ${BOOTSTRAP_TOKEN} -s ${CA_CERT_HASH}
```

It figures out your OS, if it is supported. Currently supports:

* Ubuntu-16.04
* Ubuntu-18.04
* Ubuntu-20.04
* Amazon Linux 2

If you have issues with caches - e.g. trying to use immediately after an update to this repository - override any caching with:

```console
curl -H 'Cache-Control: no-cache' https://raw.githubusercontent.com/deitch/kubeadm-install/master/install.sh
```

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
