# Dependency installation steps for Debian GNU/Linux 9.x (stretch)

This document assumes you are starting from a fresh install of Debian in the 9.x series.

Most recently tested 2018-04-23 with the following debian release:

```
$ lsb_release --description
Description:	Debian GNU/Linux 9.4 (stretch)
```



## Set up Debian backports

This will aid in the installation of VirtualBox.

Add stretch-backports to your system's apt sources with 'main' and 'contrib' entries.

```
echo "deb http://ftp.debian.org/debian stretch-backports main contrib" | sudo tee /etc/apt/sources.list.d/stretch-backports.list
```

You may also select a different mirror site from Debian's list at https://www.debian.org/mirror/list

For instance, to instead use Debian's primary United States mirror:

```
echo "deb http://ftp.us.debian.org/debian stretch-backports main contrib" | sudo tee /etc/apt/sources.list.d/stretch-backports.list
```

Update your local package index

```
sudo apt-get update
```

Source: https://backports.debian.org/Instructions/



# Install VirtualBox

```
sudo apt install virtualbox
```

Most recently tested 2018-04-23 with the following virtualbox release:

```
$ virtualbox --help
Oracle VM VirtualBox Manager 5.1.30_Debian
...
```



## Install git

```
$ sudo apt-get install git
```

Most recently tested 2018-04-23 with the following git release:

```
$ git --version
git version 2.11.0
```



# Install Vagrant 2.0.3 or higher

As of this writing, the Vagrant version that Debian uses in its "stretch" release is 1.9.x so we
suggest getting a package from Vagrant's web site:

```
wget -c https://releases.hashicorp.com/vagrant/2.0.3/vagrant_2.0.4_x86_64.deb
sudo dpkg -i vagrant_2.0.4_x86_64.deb
```

Most recently tested 2018-04-23 with the following vagrant release:

```
$ vagrant --version
Vagrant 2.0.4
```



# Install pip (python package manager)

We'll use this to install ansible, so we can be on a more current version of ansible than the one
Debian provides with its 'stretch' distribution.

```
sudo apt-get install python-pip
```

Most recently tested 2018-04-23 with the following pip release:

```
$ pip --version
pip 9.0.1 from /usr/lib/python2.7/dist-packages (python 2.7)
```



# Install ansible 2.4.x or higher

```
pip install --user -U ansible
```

This will place an `ansible` executable in `~/.local/bin`, so add the following to `~/.profile`:

```
# set PATH so it includes user's private .local/bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi
```

Then source .profile in your shell session:

```
$ source .profile
```

Most recently tested 2018-04-23 with the following ansible release:

```
$ ansible --version
ansible 2.5.1
...
```



# Install GnuPG 2.x (2.11.18 or greater)

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
$ sudo apt-get install gnupg2
```

Most recently tested 2018-04-23 with the following GnuPG release:

```
$ gpg2 --version
gpg (GnuPG) 2.1.18
...
```
