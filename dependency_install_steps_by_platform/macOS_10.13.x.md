# Dependency installation steps for macOS 10.x (aka High Sierra)

This document assumes you are starting from a fresh install of macOS.

Most recently tested 2018-04-17 with the following macOS release:

```
$ sw_vers
ProductName:  Mac OS X
ProductVersion: 10.13.4
BuildVersion: 17E199
```



## Make sure Git is installed

macOS includes git, so you should already have that. It may prompt you to set up developer tools if
you're using it for the first time.

Most recently tested 2018-04-17 with the following git release:

```
$ git --version
git version 2.15.1 (Apple Git-101)
```



## Install Homebrew

Homebrew's site gives a shell command to download and install it
https://brew.sh/

To update both the installed homebrew version and its list of formulae:

```
$ brew update
```

To upgrade software installed via brew:

```
$ brew upgrade <formula name>
```

Homebrew has a search page you can use to look up package names: http://formulae.brew.sh/

Most recently tested 2018-04-23 with the following Homebrew release:

```
$ brew --version
Homebrew 1.6.2
Homebrew/homebrew-core (git revision 2251; last commit 2018-04-23)
```



## Install Homebrew-Cask

Software projects offered as mac-specific downloads tend to come in one of two forms:
- a file users can drag into their Applications folder
- an installer application for users to execute

Homebrew-Cask is an extension to Homebrew designed to extend the benefits of package management to
this category of mac software.

Homebrew-Cask's site gives a shell command to download and install it: https://caskroom.github.io/

The same `brew update` command given above to update Homebrew will also update Homebrew-Cask.

To upgrade software installed via cask:

```
$ brew cask upgrade <cask-name>
```

To upgrade all installed casks:

```
$ brew cask upgrade
```

Homebrew Cask also has a search page for package names: https://caskroom.github.io/search

Most recently tested 2018-04-23 with the following Homebrew-Cask release:

```
$ brew cask --version
Homebrew-Cask 1.6.2
caskroom/homebrew-cask (git revision 5f4c5d; last commit 2018-04-23)
```



## Install Virtualbox

```
$ brew cask install virtualbox
```

Most recently tested 2018-04-23 with the following Virtualbox release:

```
$ virtualbox --help
Oracle VM VirtualBox Manager 5.2.10
...
```



## Install Vagrant

```
$ brew cask install vagrant
```

Most recently tested 2018-04-23 with the following Vagrant release:

```
$ vagrant --version
Vagrant 2.0.4
```



## Install Ansible

```
$ brew install ansible
```

Most recently tested 2018-04-23 with the following Ansible release:

```
$ ansible --version
ansible 2.5.1
...
```



## Install GnuPG 2.x (2.11.18 or greater)

```
$ brew install gnupg
```

Most recently tested 2018-04-23 with the following GnuPG release:

```
$ gpg --version
gpg (GnuPG) 2.2.6
```



## Make sure 'gpg2' can be called

As of this writing, we have ansible tasks that make calls to 'gpg2' while the gnupg homebrew package
installs the executable 'gpg'.

```
$ type gpg
gpg is /usr/local/bin/gpg
$ type gpg2
-bash: type: gpg2: not found
```

If this is still the case, a simple workaround option is to create a symlink from gpg2 to gpg:

```
$ ln -s /usr/local/bin/gpg /usr/local/bin/gpg2
$ gpg2 --version
gpg (GnuPG) 2.2.6
[...]
$
```

If you find that this issue has been resolved, please remove this step :)
