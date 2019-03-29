# Dependency installation steps for Ubuntu 18.04.x LTS (Bionic Beaver)

This document assumes you are starting from a fresh install of Ubuntu in the 18.04.x series.


## Install Git, VirtualBox, and rng-tools

```
$ sudo apt install git virtualbox rng-tools
```



# Install Vagrant 2.0.3 or higher

As of this writing, the vagrant version that Ubuntu 18.04 uses is 2.0.2 so we suggest a later
release in the 2.0.x series.

```
wget -c https://releases.hashicorp.com/vagrant/2.2.4/vagrant_2.2.4_x86_64.deb
sudo dpkg -i vagrant_2.2.4_x86_64.deb
rm vagrant_2.2.4_x86_64.deb
```

Most recently tested 2019-03-26 with the following vagrant release:

```
$ vagrant --version
Vagrant 2.2.4
```



## Choice: Install Ansible via apt now or pip later

You can install ansible to a system-wide location using Ubuntu's apt tool, which will be a less
current version, with infrequent updates, or choose another method described later to install it via
a python package in a project-local virtual environment. The apt method is a bit easier, while the
python method is ansible's native distribution channel and will be more current and more frequently
updated.

If you choose the apt option, run this command:

```
$ sudo apt install ansible
```

If you choose the python/pip option, run this command:

```
$ sudo apt install python3-venv
```



# Install direnv (Optional/Recommended)

This tool sets and unsets environment variables as you change directories in a shell session,
providing a convenient facility for setting up project-specific configuration.

```
sudo apt install direnv
```

To activate direnv when starting bash (the default shell on Ubuntu 18.04), add the following line to
the end of `~/.bashrc`:

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




## Versions

Most recently tested 2018-03-26 with the following versions:


### Ubuntu

```
$ lsb_release --description
Description:	Ubuntu 18.04 LTS
```


### Git

```
$ git --version
git version 2.17.1
```


### VirtualBox

```
$ virtualbox --help
Oracle VM VirtualBox Manager 5.2.18_Ubuntu
...
```


### Ansible

```
$ ansible --version
ansible 2.5.1
[...]
```


### direnv

```
$ direnv --help
direnv v2.15.0
[...]
```
