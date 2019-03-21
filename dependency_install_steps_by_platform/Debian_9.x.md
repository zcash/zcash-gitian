# Dependency installation steps for Debian GNU/Linux 9.x (stretch)

This document assumes you are starting from a fresh install of Debian in the 9.x series.

Most recently tested 2019-03-21 with the following debian release:

```
$ lsb_release --description
Description:	Debian GNU/Linux 9.8 (stretch)
```



# Install VirtualBox

Virtualbox is the configured VM provider in this project's Vagrantfile.

Add Oracle's VirtualBox apt repository to your system's apt sources:

```
sudo apt-add-repository "deb http://download.virtualbox.org/virtualbox/debian $(lsb_release -sc) contrib"
```

Verify that the source was added:

```
$ grep -iR virtualbox /etc/apt/sources.list*
/etc/apt/sources.list:deb http://download.virtualbox.org/virtualbox/debian stretch contrib
/etc/apt/sources.list:# deb-src http://download.virtualbox.org/virtualbox/debian stretch contrib
```

Download and register the public gpg key used by Oracle to secure the above
repository:

```
$ wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add -
OK
```

Verify that the key was added

```
$ apt-key list "B9F8 D658 297A F3EF C18D  5CDF A2F6 83C5 2980 AECF"
pub   rsa4096 2016-04-22 [SC]
      B9F8 D658 297A F3EF C18D  5CDF A2F6 83C5 2980 AECF
uid           [ unknown] Oracle Corporation (VirtualBox archive signing key) <info@virtualbox.org>
sub   rsa4096 2016-04-22 [E]
```

Update your local apt package metadata

```
$ sudo apt update
[...]
```

This command will show the available versions of virtualbox from the apt
repository:

```
$ sudo apt install virtualbox
Reading package lists... Done
Building dependency tree       
Reading state information... Done
Package virtualbox is a virtual package provided by:
  virtualbox-6.0 6.0.4-128413~Debian~stretch
  virtualbox-5.2 5.2.26-128414~Debian~stretch
  virtualbox-5.1 5.1.38-122592~Debian~stretch
  virtualbox-5.0 5.0.40-115130~Debian~stretch
You should explicitly select one to install.

E: Package 'virtualbox' has no installation candidate
```

Decide on the version you want and specify the version number to install it:

```
$ sudo apt install virtualbox-6.0 -y
[...]
```

Source: https://www.virtualbox.org/wiki/Linux_Downloads#Debian-basedLinuxdistributions

Most recently tested 2019-03-21 with the following virtualbox release:

```
$ virtualbox --help
Oracle VM VirtualBox VM Selector v6.0.4
[...]
```



## Install git

```
$ sudo apt install git
```

Most recently tested 2019-03-21 with the following git release:

```
$ git --version
git version 2.11.0
```



# Install Vagrant 2.0.3 or higher

As of this writing, the Vagrant version that Debian uses in its "stretch" release is 1.9.x so we
suggest getting a package from Vagrant's web site:

```
wget -c https://releases.hashicorp.com/vagrant/2.2.4/vagrant_2.2.4_x86_64.deb
sudo dpkg -i vagrant_2.2.4_x86_64.deb
rm vagrant_2.2.4_x86_64.deb
```

Most recently tested 2019-03-21 with the following vagrant release:

```
$ vagrant --version
Vagrant 2.2.4
```



# Install GnuPG 2.x (2.1.18 or greater)

This is likely already installed and runnable via 'gpg'

```
$ gpg --version
gpg (GnuPG) 2.1.18

```

We want to be able to run it using the command 'gpg2'. For that we can install the gnupg2 package.

According to the description of that package, “This is a dummy transitional package that provides
symlinks from gpg2 to gpg.”
https://packages.debian.org/stretch/gnupg2

```
$ sudo apt install gnupg2
```

Most recently tested 2019-02-13 with the following GnuPG release:

```
$ gpg2 --version
gpg (GnuPG) 2.1.18
...
```
