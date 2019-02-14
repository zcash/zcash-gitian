# Dependency installation steps for Ubuntu 18.04.x LTS (Bionic Beaver)

This document assumes you are starting from a fresh install of Ubuntu in the 18.04.x series.

Most recently tested 2018-05-21 with the following ubuntu release:

```
$ lsb_release --description
Description:	Ubuntu 18.04 LTS
```



## Install Git, VirtualBox, Ansible, GnuPG, and rng-tools

```
$ sudo apt install git virtualbox ansible gnupg2 rng-tools
```



## Install Vagrant 2.0.3 or higher

As of this writing, the vagrant version that Ubuntu 18.04 uses is 2.0.2 so we suggest a later
release in the 2.0.x series.

```
$ wget https://releases.hashicorp.com/vagrant/2.0.4/vagrant_2.0.4_x86_64.deb
...
$ sudo apt install ./vagrant_2.0.4_x86_64.deb
...
$ dpkg --status vagrant
Package: vagrant
Status: install ok installed
...
$ rm ./vagrant_2.0.4_x86_64.deb
```




## Versions

Most recently tested 2018-05-21 with the following versions:


### Ubuntu

```
$ lsb_release --description
Description:	Ubuntu 18.04 LTS
```


### Git

```
$ git --version
git version 2.17.0
```


### VirtualBox

```
$ virtualbox --help
Oracle VM VirtualBox Manager 5.2.10_Ubuntu
...
```


### Ansible

```
$ ansible --version
ansible 2.5.1
```


### GnuPG

```
$ gpg2 --version
gpg (GnuPG) 2.2.4
...
```


### Vagrant

```
$ vagrant --version
Vagrant 2.0.4
```
