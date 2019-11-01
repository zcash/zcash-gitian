# Dependency installation steps for macOS

This document assumes you are starting from a fresh install of macOS.

Most recently tested 2019-11-01 with the following macOS release:

```
% sw_vers
ProductName:	Mac OS X
ProductVersion:	10.15.1
BuildVersion:	19B88
```



## Make sure Git is installed

macOS includes git, so you should already have that. It may prompt you to set up developer tools if
you're using it for the first time.

Most recently tested 2019-11-01 with the following git release:

```
% git --version
git version 2.21.0 (Apple Git-122)
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

Homebrew has a search page you can use to look up formula names: http://formulae.brew.sh/

Most recently tested 2019-11-01 with the following Homebrew release:

```
% brew --version
Homebrew 2.1.15
Homebrew/homebrew-core (git revision de439b; last commit 2019-11-01)
Homebrew/homebrew-cask (git revision 3a397; last commit 2019-11-01)
```

That last line about "homebrew-cask" refers to a subcommand 'cask' that can manage the types of
installs mac users ordinarily do manually - the "drag to the applications folder" type and the "run
an installer" type.

We'll use both "brew" and "brew cask" install methods in the steps below.



## Install Virtualbox

This one may fail on the first attempt with a prompt to allow software signed by Oracle. After doing
that, the second attempt should succeed.

```
$ brew cask install virtualbox
```

Most recently tested 2019-11-01 with the following Virtualbox release:

```
% virtualbox --help
Oracle VM VirtualBox VM Selector v6.0.14
[...]
```



## Install Vagrant

```
$ brew cask install vagrant
```

Most recently tested 2019-11-01 with the following Vagrant release:

```
% vagrant --version
Vagrant 2.2.6
```



## Install GnuPG 2.x (2.11.18 or greater)

```
$ brew install gnupg
```

Most recently tested 2019-11-01 with the following GnuPG release:

```
% gpg --version
gpg (GnuPG) 2.2.17
libgcrypt 1.8.5
[...]
```



## Install Python 3.x

As of this writing, python 3.7.3 is installed by default in macOS, which should work fine. You can
optionally install the 'python' homebrew package to get a later version.

```
$ brew install python
```

Note that to run python 3.x you need to use the name `python3`; running `python` will run python
2.x.

Most recently tested 2019-11-01 with the following Python release:

```
% python3 --version
Python 3.7.3
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

direnv works by incorporating a call to `_direnv_hook` in the `PROMPT_COMMAND` shell variable. You
can check that this was done by starting a new bash session and checking whether that value is
present:

```
$ echo $PROMPT_COMMAND
_direnv_hook;[...]
```

direnv also supports several other shells -- zsh, fish, tcsh, and elvish as of this writing. Its
website includes instructions for enabling each of the shells it supports.

Most recently tested 2019-11-01 with the following direnv release:

```
$ direnv --version
2.20.1
```
