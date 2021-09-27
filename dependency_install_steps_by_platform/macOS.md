# Dependency installation steps for macOS

This document assumes you are starting from a fresh install of macOS.

Most recently tested 2021-09-21 with the following macOS release:

```
% sw_vers
ProductName:	macOS
ProductVersion:	11.5.2
BuildVersion:	20G95
```



## Make sure Git is installed

macOS includes git, so you should already have that. It may prompt you to set up developer tools if
you're using it for the first time.

Most recently tested 2021-04-09 with the following git release:

```
% git --version
git version 2.24.3 (Apple Git-128)
```



## Install Homebrew

Homebrew's site gives a shell command to download and install it
https://brew.sh/

To update both the installed homebrew version and its list of formulae:

```
% brew update
```

To upgrade software installed via brew:

```
$ brew upgrade <formula name>
```

Homebrew has a search page you can use to look up formula names: http://formulae.brew.sh/

Most recently tested 2021-09-21 with the following Homebrew release:

```
% brew --version
Homebrew 3.2.13
Homebrew/homebrew-core (git revision 9a917cc5fcd; last commit 2021-09-21)
Homebrew/homebrew-cask (git revision 0892bc690f; last commit 2021-09-21)
```



## Install Virtualbox

This one may fail on the first attempt with a prompt to allow software signed by Oracle. After doing
that, the second attempt should succeed.

```
$ brew install virtualbox
```

Most recently tested 2021-09-21 with the following Virtualbox release:

```
% VBoxManage --version
6.1.26r145957
```



## Install Vagrant

As of 2021-09-21, the current vagrant version (2.2.18) conflicts with the most recent version of 
vagrant-scp (0.5.7).

Github issues for that version conflict:
https://github.com/hashicorp/vagrant/issues/12504
https://github.com/invernizzi/vagrant-scp/issues/46

When that conflict is resolved, with a new release of vagrant or vagrant-scp or both, we should be
able to `brew install vagrant` here. Until then, a workaround is to install vagrant 2.2.16:

```
$ curl -O -L https://github.com/Homebrew/homebrew-cask/raw/015bd57c9637d517f1a814e46a1ece5de570c263/Casks/vagrant.rb
$ brew install --cask ./vagrant.rb
```

(after the above steps the `vagrant.rb` file can be removed)

Most recently tested 2021-09-21 with the following Vagrant release:

```
% vagrant --version
Vagrant 2.2.16
```



## Install GnuPG 2.x (2.11.18 or greater)

```
$ brew install gnupg
```

Most recently tested 2021-09-21 with the following GnuPG release:

```
% gpg --version
gpg (GnuPG) 2.3.2
libgcrypt 1.9.4
[...]
```



## Install Python 3.x

As of this writing, python 3.8.2 is installed by default in macOS, which should work fine. You can
optionally install the 'python' homebrew package to get a later version.

```
$ brew install python
```

Note that to run python 3.x you need to use the name `python3`; running `python` will run python
2.x.

Most recently tested 2021-09-21 with the following Python release:

```
% python3 --version
Python 3.9.7
```



# Install direnv (Optional/Recommended)

This tool sets and unsets environment variables as you change directories in a shell session,
providing a convenient facility for setting up project-specific configuration.

```
brew install direnv
```

To activate direnv when starting bash (the default shell on macOS), add the following line to the
end of `~/.profile`:

```
eval "$(direnv hook bash)"
```

direnv also supports several other shells -- zsh, fish, tcsh, and elvish as of this writing. Its
website includes instructions for enabling each of the shells it supports.

Most recently tested 2021-09-21 with the following direnv release:

```
% direnv --version
2.28.0
```
