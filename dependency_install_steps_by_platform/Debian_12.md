# Dependency installation steps for Debian 12 (bookworm)

This document assumes you are starting from a fresh install of Debian 12 (bookworm).

Most recently tested 2025-04-17 with the following debian release:

```
$ lsb_release --description
Description:	Debian GNU/Linux trixie/sid
```


# Install VirtualBox

Virtualbox is the configured VM provider in this project's Vagrantfile.

First, check whether virtualbox is installed. Some systems may have it already:

```
$ virtualbox --help
Oracle VM VirtualBox VM Selector v7.0.20_Debian
[...]
```

(If it is installed, you can probably skip this step. Note that virtualbox installs linux kernel
modules which need to be kept in sync with the virtualbox apt package, so if you decide to change to
a different version, be sure to uninstall completely (including the kernel modules) before
reinstalling.)

First find the codename of your Debian release.
```
export DEBIAN_CODENAME=$(lsb_release -sc)
echo $DEBIAN_CODENAME
```

If this outputs `trixie`, replace it with the most similar release, e.g. `export DEBIAN_CODENAME=bookworm`.

Add Oracle's VirtualBox apt repository to your system's apt sources:

```
sudo apt-add-repository "deb http://download.virtualbox.org/virtualbox/debian $DEBIAN_CODENAME contrib"
```

Verify that the source was added:

```
$ grep -iR virtualbox /etc/apt/sources.list*
/etc/apt/sources.list:deb http://download.virtualbox.org/virtualbox/debian bookworm contrib
/etc/apt/sources.list:# deb-src http://download.virtualbox.org/virtualbox/debian bookworm contrib
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
$ sudo apt show virtualbox
```

Decide on the version you want and specify the version number to install it:

```
$ sudo apt install 7.0.20-dfsg-1
[...]
```

See https://www.virtualbox.org/wiki/Linux_Downloads#Debian-basedLinuxdistributions
if you run into any difficulties.

Most recently tested 2025-04-17 with the following virtualbox release:

```
$ virtualbox --help
Oracle VM VirtualBox VM Selector v7.0.20_Debian
[...]
```


## Install git

```
$ sudo apt install git
```

Most recently tested 2025-04-17 with the following git release:

```
$ git --version
git version 2.45.2
```


# Install Vagrant 2.0.3 or higher

As of this writing, the Vagrant version that Debian uses in its "bookworm" release is 2.3.6
which is quite sufficient.

Most recently tested 2025-04-17 with the following vagrant release:

```
$ vagrant --version
Vagrant 2.3.6
```


# Install virtualenv support

`virtualenv` is a python module used to create isolated project-specific environments, so that
projects on the same computer can each use their own version of the python executable and their
own set of installed python modules.

Currently there is a problem with using Python 3.12 or higher to build `zcashd`, so you will
need Python 3.11. However, some versions of the Python 3.11 packages on Debian are broken.

This is how I (Daira-Emma) got it to work; your mileage may vary. There is a risk that this
will completely bork your system as a consequence of using mixed package sources and/or buggy
"proposed-updates" versions of packages, so be aware of that.

Make sure that you have the following line in `/etc/apt/sources.list`:

```
deb http://deb.debian.org/debian bookworm-proposed-updates main
```

Optionally add `contrib non-free-firmware` or similar to match your existing package
sources. I also have these lines:

```
deb [arch=amd64,i386] http://security.debian.org/debian-security bookworm-security main
deb-src http://security.debian.org/debian-security bookworm-security main contrib non-free-firmware
```

Then do:

```
sudo apt update
sudo apt install python3.11 python3.11-dev
python3.11 --version
```

If `python3.11` will not install properly, you might first need to remove existing `python3.11*`
and `libpython3.11*` packages using `dpkg -r` and then retry, but that is quite risky since
other packages may depend on them.

Hopefully `pip` is installed; test that using `python3.11 -m pip --version`. If it is not then do:

```
curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11
python3.11 -m pip --version
```

Then upgrade `pip` and install `virtualenv`:

```
python3.11 -m pip install --upgrade pip
python3.11 -m pip install virtualenv
```

Most recently tested 2025-04-17 with the following `virtualenv` release:

```
$ python3.11 -m virtualenv --version
virtualenv 20.26.6 from /usr/lib/python3/dist-packages/virtualenv/__init__.py
```

(Note that after you have created a virtualenv below, the version inside that environment
might be different to the one installed on the system.)


# Install direnv (Optional/Recommended)

This tool sets and unsets environment variables as you change directories in a shell session,
providing a convenient facility for setting up project-specific configuration.

```
sudo apt install direnv
```

To activate direnv when starting bash (the default shell on Debian 9), add the following line to the
end of `~/.bashrc`:

```
eval "$(direnv hook bash)"
```

direnv works by incorporating a call to `_direnv_hook` in the `PROMPT_COMMAND` shell variable. You
can check that this was done by starting a new bash session and checking whether that value is
present:

```
$ echo $PROMPT_COMMAND
_direnv_hook;
```

direnv also supports several other shells -- zsh, fish, tcsh, and elvish as of this writing. Its
website includes instructions for enabling each of the shells it supports.

Most recently tested 2025-04-17 with the following direnv release:

```
$ direnv --help
direnv v2.32.1
[...]
```
