# Dependency installation steps for macOS

This document assumes you are starting from a fresh install of macOS.

Most recently tested 2021-04-09 with the following macOS release:

```
% sw_vers
ProductName:	macOS
ProductVersion:	11.2.3
BuildVersion:	20D91
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

Most recently tested 2021-02-22 with the following Homebrew release:

```
% brew --version
Homebrew 3.0.11
Homebrew/homebrew-core (git revision 5aa04149e9; last commit 2021-04-09)
Homebrew/homebrew-cask (git revision 77095bcb6b; last commit 2021-04-09)
```



## Install Virtualbox

This one may fail on the first attempt with a prompt to allow software signed by Oracle. After doing
that, the second attempt should succeed.

```
$ brew install virtualbox
```

Most recently tested 2021-04-09 with the following Virtualbox release:

```
% VBoxManage --version
6.1.18r142142
```



## Install Vagrant

```
$ brew install vagrant
```

Most recently tested 2021-04-09 with the following Vagrant release:

```
% vagrant --version
Vagrant 2.2.15
```



## Install GnuPG 2.x (2.11.18 or greater)

```
$ brew install gnupg
```

Most recently tested 2021-04-09 with the following GnuPG release:

```
% gpg --version
gpg (GnuPG) 2.2.27
libgcrypt 1.9.2
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

Most recently tested 2021-02-22 with the following Python release:

```
% python3 --version
Python 3.8.2
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

Most recently tested 2021-04-09 with the following direnv release:

```
% direnv --version
2.28.0
```
