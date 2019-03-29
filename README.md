Zcash deterministic builds
==========================

This is a deterministic build environment for [Zcash](https://github.com/zcash/zcash/) that uses [Gitian](https://gitian.org/).

Gitian provides a way to be reasonably certain that the Zcash executables are really built from the exact source on GitHub and have not been tampered with. It also makes sure that the same, tested dependencies are used and statically built into the executable.

Multiple developers build from source code by following a specific descriptor ("recipe"), cryptographically sign the result, and upload the resulting signature. These results are compared and only if they match is the build accepted.

More independent Gitian builders are needed, which is why this guide exists.

Requirements
------------

6GB of RAM, four cores.

Install Dependencies
--------------------

If you're using one of the following platforms, see the linked instructions for that platform:

- [Debian 9.x](dependency_install_steps_by_platform/Debian_9.x.md)
- [Ubuntu 18.04.x](dependency_install_steps_by_platform/Ubuntu_18.04.x.md)
- [macOS](dependency_install_steps_by_platform/macOS.md)


If you're not using one of the platforms that we have specific instructions for, this is the list of
dependencies we want. Please document the steps involved and we can add another platform to the list
above!

- [Git](https://git-scm.com/)
- [VirtualBox](https://www.virtualbox.org/)
- [Vagrant](https://www.vagrantup.com/) 2.0.3 or higher
- [GnuPG](https://www.gnupg.org/) 2.x (2.11.18 or greater)
- [Python](https://www.python.org/) 3.x (with `venv` support in case that is packaged separately)
- [direnv](https://direnv.net/) (Optional/Recommended)



Configuration
-------------

## Configure git

We want a configuration file in the home directory of the account you'll be working in. This will
determine how you are identified on the projects you contribute to. These settings can be overridden
on a per-project basis.

Git provides some convenient command options for setting this up:

```
$ git config --global user.name "Harry Potter"
$ git config --global user.email "hpotter@hogwarts.wiz"
```

Checking that this worked:

```
$ git config user.name
Harry Potter
$ git config user.email
hpotter@hogwarts.wiz
```

This is all the git configuration needed for the steps below, but here is a good reference for
further reading on configuring git:

https://git-scm.com/book/en/v2/Customizing-Git-Git-Configuration



## Decide on an ssh keypair to use when uploading build signatures to GitHub

You can generate a keypair specifically for connecting to GitHub like this:

```
$ ssh-keygen -t rsa -b 4096 -C "hpotter@hogwarts.wiz" -f ~/.ssh/github_id_rsa -N ''
Generating public/private rsa key pair.
Your identification has been saved in /Users/hpotter/.ssh/github_id_rsa.
Your public key has been saved in /Users/hpotter/.ssh/github_id_rsa.pub.
The key fingerprint is:
SHA256:w1ZAgf+Ge+R662PU18ASqx8sZYfg9OxKhE/ZFf9zwvE hpotter@hogwarts.wiz
The key's randomart image is:
+---[RSA 2048]----+
|       o+.    .. |
|      .  .o . .. |
|       . +.* *. .|
|       .o.= X.+o.|
|        S* B oo+E|
|       ...X = ..+|
|         B + o   |
|        . B .    |
|        .*oo     |
+----[SHA256]-----+
```

Some explanation of the arguments used in the above example:

```
    -t rsa                         Use a key type of RSA

    -C "hpotter@hogwarts.wiz"      Provide an identity to associate with the key (default is
                                   user@host in the local environment)

    -f ~/.ssh/github_id_rsa        Path to the private key to generate. The corresponding public key
                                   will be saved at ~/.ssh/github_id_rsa.pub

    -N ''                          Passphrase for the generated key. An empty string as shown here
                                   means save the private key unencrypted.
```



# Set up your ssh keypair for use with GitHub

[Add the new key to your GitHub account.](https://help.github.com/articles/adding-a-new-ssh-key-to-your-github-account/)

Add an entry to `~/.ssh/config` (create this file if necessary) telling ssh to use the keypair you
generated above when connecting to github.com.

For instance:

```
Host github.com
  User harrypotter
  PreferredAuthentications publickey
  IdentityFile /home/hpotter/.ssh/github_id_rsa
  AddKeysToAgent yes
```

The 'User' entry should match your github username.

Test that ssh will successfully use your new key to connect to GitHub.

```
$ ssh -T git@github.com
The authenticity of host 'github.com (192.30.253.112)' can't be established.
RSA key fingerprint is SHA256:nThbg6kXUpJWGl7E1IGOCspRomTxdCARLviKw6E5SY8.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added 'github.com,192.30.253.112' (RSA) to the list of known hosts.
Hi harrypotter! You've successfully authenticated, but GitHub does not provide shell access.
$
```



## Clone this git project on your machine

From a location where you want to place your local clone of this repository (e.g. `~/Projects`)

```
$ git clone git@github.com:zcash/zcash-gitian.git
```

cd into the project repo

```
$ cd zcash-gitian
zcash-gitian
```


## Copy example environment configuration files

The files `.env.example` and `.envrc.example` are tracked in the repo as example configurations you
should be able to use to get started. The filenames `.env` and `.envrc` are `.gitignore`'d to allow
you to easily make local customizations that don't show up as untracked changes.

Note that `.envrc` is probably only useful if you are using `direnv`. If you're not, you can ignore
that file and the places below that talk about it, and use your preferred way of managing
environment variables instead.

```
zcash-gitian$ cp .env.example .env
zcash-gitian$ cp .envrc.example .envrc
direnv: error .envrc is blocked. Run `direnv allow` to approve its content.
zcash-gitian$
```

More on that above message in the following section...



## Enable auto-execution of .envrc

If you installed and activated `direnv`, it will detect when `.envrc` is created in your current
directory, as shown above. As a security precaution, it won't automatically run it without your
approval (to prevent untrusted code from doing something malicious). Let's take a look at what's in
the file:

```
zcash-gitian$ cat .envrc
source_up
dotenv

export GIT_NAME=`git config user.name`
export GIT_EMAIL=`git config user.email`
direnv: error .envrc is blocked. Run `direnv allow` to approve its content.
zcash-gitian$
```

Some explanation of the lines in the above `.envrc` file:

```
`source_up`                        Load any .envrc higher up in the folder structure. So if for
                                   example you place an `.envrc` in your home directory, variables
                                   set there will still be available within this project, rather
                                   than being overridden by this project's `.envrc`.

`dotenv`                           Set the environment variables defined in `.env`. Think of
                                   `.envrc` as code (it runs in a bash interpreter with some extra
                                   functions added) and `.env` as data (you can basically just set
                                   literal values, and each update to it doesn't require approval).


export GIT_NAME=`git config user.name`
export GIT_EMAIL=`git config user.email`

                                   Use your local git configuration values for the name and email
                                   that will be used to add build signatures inside the virtual
                                   environment.
```


If you're ok with running `.envrc`, follow the directions in the prompt to allow it.

```
zcash-gitian$ echo $ZCASH_GIT_REPO_URL

direnv: error .envrc is blocked. Run `direnv allow` to approve its content.
zcash-gitian$ direnv allow
direnv: loading .envrc
direnv: export +GIT_EMAIL +GIT_NAME +GPG_KEY_ID +GPG_KEY_NAME +ZCASH_GIT_REPO_URL +ZCASH_VERSION
zcash-gitian$ echo $ZCASH_GIT_REPO_URL
https://github.com/zcash/zcash
zcash-gitian$
```

A variable defined in `.env` is now active in our environment. If we leave this project, it is
unloaded. When we return, it is reloaded:

```
zcash-gitian$ cd ..
direnv: unloading
$ echo $ZCASH_GIT_REPO_URL

$ cd zcash-gitian/
direnv: loading .envrc
direnv: export +GIT_EMAIL +GIT_NAME +GPG_KEY_ID +GPG_KEY_NAME +ZCASH_GIT_REPO_URL +ZCASH_VERSION
zcash-gitian$ echo $ZCASH_GIT_REPO_URL
https://github.com/zcash/zcash
zcash-gitian$
```

Project-specific environment settings will come in handy in the next step, when we'll create an
isolated python virtual environment specifically for use with this project.



## Create a python virtual environment for this project

Note: The main purpose of this part is to get a current version of ansible, and keep it locally
within this project. If you already installed ansible (e.g. from an OS package manager like apt),
you can skip this part and the following parts about pip and pip packages.

When creating a virtual environment, call the python executable you want the virtual environment to
use. The location and version will depend on your specific setup -- your OS may provide a suitably
current python interpreter, or you may have built and installed one yourself. If it's in your PATH,
a command like `type python3` should tell you where it is installed on your system. For example:

```
zcash-gitian$ type python3
python3 is /usr/local/bin/python3
zcash-gitian$ /usr/local/python3 --version
Python 3.7.2
```

We can use python's built-in `venv` module to create a virtual environment:

```
zcash-gitian$ /usr/local/bin/python3 -m venv local/python_v3.7.2_venv
```

Translation: "Create a virtual environment at ./local/python_v3.7.2_venv".

The project subdirectory `local` is `.gitignored` to provide a convenient location for files we
don't want to commit and track in version control.

You should now have a tree of directories and files in `local/python_v3.7.2_venv`:

```
zcash-gitian$ ls -F local/python_v3.7.2_venv/
bin/    include/  lib/    pyvenv.cfg
```

Inside the `bin` directory, among other things, are the entries `python` and `python3`, which are
symlinks that point back to the `python3` executable we used to create this environment:

```
zcash-gitian$ ls -F local/python_v3.7.2_venv/bin/
activate        activate.fish   easy_install-3.7*  pip3*       python@
activate.csh    easy_install*   pip*               pip3.7*     python3@
```

A python virtual environment is 'active' if the python interpreter being executed is run from its
path inside the environment's `bin` directory. Even though the file being executed is the same
whether run directly or via a symlink, it pays attention to the path of the command that was used to
run it.

An `activate` script is provided, and you can use that, but if you're using `direnv` you can set up
a simple automatic activation for the project directory by adding the following line to `.envrc`:

```
load_prefix local/python_v3.7.2_venv
```

The command `load_prefix` is provided by `direnv` to modify a whole set of common "path" variables
(including PATH) according to a common unix pattern.

Let's add that line now:

```
zcash-gitian$ echo "load_prefix local/python_v3.7.2_venv" >> .envrc
direnv: error .envrc is blocked. Run `direnv allow` to approve its content.
zcash-gitian$ direnv allow
direnv: loading .envrc
direnv: export +CPATH +GIT_EMAIL +GIT_NAME +GPG_KEY_ID +GPG_KEY_NAME +LD_LIBRARY_PATH +LIBRARY_PATH +MANPATH +PKG_CONFIG_PATH +ZCASH_GIT_REPO_URL +ZCASH_VERSION ~PATH
zcash-gitian$
```

When the content of `.envrc` is changed, it needs to be approved again (another security
precaution). Then, several variables were set or updated to add paths within our virtual environment
directory at the front (left side) of the list. Let's look at PATH and its effect on which `python`
locations we default to:

```
zcash-gitian$ echo $PATH
/Users/harrypotter/Projects/zcash-gitian/local/python_v3.7.2_venv/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games
zcash-gitian$ type python
python is /Users/harrypotter/Projects/zcash-gitian/local/python_v3.7.2_venv/bin/python
zcash-gitian$ type python3
python3 is /Users/harrypotter/Projects/zcash-gitian/local/python_v3.7.2_venv/bin/python3
```

Since the `python` and `python3` commands will now run from the locations we've installed into our
project's virtual environment while we are in the project directory, we can consider the virtual
environment active when using a shell at (or below) that location.



## Upgrade pip

`pip` has a command to upgrade itself. Let's go ahead and run that:

```
zcash-gitian$ pip --version
pip 18.1 from /Users/harrypotter/Projects/zcash-gitian/local/python_v3.7.2_venv/lib/python3.7/site-packages/pip (python 3.7)
zcash-gitian$ pip install --upgrade pip
Collecting pip
[...]
Successfully installed pip-19.0.3
```



## Install pip packages

We have some dependencies to install as python packages, using the pip package manager installed
above. The set we need, with version numbers managed via git, is in `requirements-pip.lock`; we can
run `pip install` with that file as input:

```
zcash-gitian$ pip install --requirement requirements-pip.lock
```

Check that you can run `ansible` from the command line:

```
zcash-gitian$ ansible --version
ansible 2.7.9
[...]
zcash-gitian$
```



## Decide on a gpg keypair to use for Gitian

You can generate a keypair specifically for Zcash Gitian builds with a command like the one below.


```
zcash-gitian$ gpg --quick-generate-key --batch --passphrase '' "Harry Potter (zcash gitian) <hpotter@hogwarts.wiz>"
gpg: key 3F0C2117D53A4A49 marked as ultimately trusted
gpg: directory '/home/hpotter/.gnupg/openpgp-revocs.d' created
gpg: revocation certificate stored as '/home/hpotter/.gnupg/openpgp-revocs.d/3F14A629C06FA31D59C64FE93F0C2117D53A4A49.rev'
```

Some explanation of the arguments used in the above example:

    --quick-generate-key --batch   This combination of options allows options to be given on the
                                   command line. Other key generation options use interactive
                                   prompts.

    --passphrase ''                Passphrase for the generated key. An empty string as shown here
                                   means save the private key unencrypted.

    "Name (Comment) <Email>"       The user id (also called uid) to associate with the generated
                                   keys. Concatenating a name, an optional comment, and an email
                                   address using this format is a gpg convention.


You can check that the key was generated and added to your local gpg key database, and see its
fingerprint value, like this:
```
zcash-gitian$ gpg --list-keys
/home/hpotter/.gnupg/pubring.kbx
----------------------------------
pub   rsa2048 2018-04-23 [SC] [expires: 2020-04-22]
      3F14A629C06FA31D59C64FE93F0C2117D53A4A49
uid           [ultimate] Harry Potter (zcash gitian) <hpotter@hogwarts.wiz>
sub   rsa2048 2018-04-23 [E]
```

Update your `GPG_KEY_ID` and `GPG_KEY_NAME` variables in `.env` as follows:

- `GPG_KEY_ID`: In the example output shown here, this is the 40 character string
`3F14A629C06FA31D59C64FE93F0C2117D53A4A49`. Some versions of gpg may truncate this value, e.g. to 8
or 16 characters. You should be able to use the truncated value.

- `GPG_KEY_NAME`: This is passed as the '--signer' argument to Gitian, and used as the name of a
directory for your signatures in our `gitian.sigs` repository. We suggest using the username portion
of the email address associated with your GPG key. In our example this is `hpotter`.



## Install Vagrant plugins

This project uses some 3rd party Vagrant plugins. These dependencies are specified in `Vagrantfile`.
We can install them locally in the `.vagrant` directory with the following command:

```
zcash-gitian$ vagrant plugin install --local
```



## Configure the version of zcash you want to build and sign

Set the value of the `ZCASH_VERSION` variable in `.env` to point to the zcash commit you want to
create a signature for. Likely you want the name of a git tag, such as `v2.0.4`.



## Provision a virtual machine

From the project root directory, run:

```
zcash-gitian$ vagrant up --provision zcash-build
```

This will provision a Gitian host virtual machine that uses a Linux container (LXC) guest to perform
the actual builds.


Load your ssh key into ssh-agent
--------------------------------

Load your ssh key (for pushing signatures to github) into ssh-agent. The approach here is to allow
programs in the zcash-build VM to connect to ssh-agent to perform operations with the private key.
This way, we don't need to copy ssh keys into the VM. You can verify that the key is loaded by
running `ssh-add -l`.

```
zcash-gitian$ ssh-add -l
The agent has no identities.

zcash-gitian$ ssh-add ~/.ssh/github_id_rsa
Identity added: /home/hpotter/.ssh/github_id_rsa (/home/hpotter/.ssh/github_id_rsa)

zcash-gitian$ ssh-add -l
4096 SHA256:4fFdwJ71VIpF5cW0dqrsU7jxjctaFcAKmdQZPEqR0Y4 /home/hpotter/.ssh/github_id_rsa (RSA)
```


SSH into the VM
---------------

Vagrant should now show that the new VM is in the 'running' state:

```
zcash-gitian$ vagrant status
Current machine states:

zcash-build               running (virtualbox)

The VM is running. To stop this VM, you can run `vagrant halt` to
shut it down forcefully, or you can run `vagrant suspend` to simply
suspend the virtual machine. In either case, to restart it again,
simply run `vagrant up`.
```

Use the `vagrant ssh` command to start a shell session in the VM. Once in that session, you can use
ssh-add again to see that your forwarded key is available, and check that you can use that key to
authenticate to github.

```
zcash-gitian$ vagrant ssh zcash-build
[...]

# on the virtualbox vm
vagrant@zcash-build:~$ ssh-add -l
4096 d1:43:75:a7:95:65:9e:d4:8e:57:d8:98:58:7d:92:4c /home/hpotter/.ssh/github_id_rsa (RSA)

vagrant@zcash-build:~$ ssh -T git@github.com
Warning: Permanently added the RSA host key for IP address '192.30.253.112' to the list of known hosts.
Hi harrypotter! You've successfully authenticated, but GitHub does not provide shell access.
```


Building Zcash
--------------

Once in a shell session in the VM, we're ready to run the gitian build.

```
# on the virtualbox vm
vagrant@zcash-build:~$ ./gitian-build.sh
```

The output from `gbuild` is informative. There are some common warnings which can be ignored, e.g. if you get an intermittent privileges error related to LXC then just execute the script again. The most important thing is that one reaches the step which says `Running build script (log in var/build.log)`. If not, then something else is wrong and you should let us know.

Take a look at the variables near the top of `~/gitian-build.sh` and get familiar with its functioning, as it can handle most tasks.

It's also a good idea to regularly `git pull` on this repository to obtain updates and re-run the entire VM provisioning for each release, to ensure current and consistent state for your builder.

Generating and uploading signatures
-----------------------------------

After the build successfully completes, the gitian command `gsign` will be called, which will
generate signatures, and a commit will be added. You can cd into the gitian.sigs directory, set the
repository to point to your fork of [zcash/gitian.sigs](https://github.com/zcash/gitian.sigs), push
your updates to a branch, and then make a pull request on github.

```
cd gitian.sigs
git remote rename origin upstream
git remote add origin git@github.com:harrypotter/zcash-gitian.git
git checkout -b v2.0.4
git push origin v2.0.4
```

Signatures can be verified by running `gitian-build.sh --verify`, but set `build=false` in the script to skip building. Run a `git pull` beforehand on `gitian.sigs` so you have the latest. The provisioning includes a task which imports Zcash developer public keys to the Vagrant user's keyring and sets them to ultimately trusted, but they can also be found at `contrib/gitian-downloader` within the Zcash source repository.

Working with GPG
----------------

We provide two options for automatically importing keys into the VM, or you may choose to copy them manually. GPG keys are needed to sign the manifests which get pushed to [gitian.sigs](https://github.com/zcash/gitian.sigs).

GPG is tricky, especially if you use a smartcard and can't copy the secret key. We have a script intended to forward the gpg-agent socket into the VM, `forward_gpg_agent.sh`, but it is not currently working. If you want your full keyring to be available, you can use the following workaround involving `sshfs` and synced folders:

    vagrant plugin install vagrant-sshfs

Uncomment the line beginning with `gitian.vm.synced_folder "~/.gnupg"` in `Vagrantfile`. Ensure the destination mount point is empty. Then run:

    vagrant sshfs --mount zcash-build

Vagrant synced folders may also work natively with `vboxfs` if you install VirtualBox Guest Additions into the VM from `contrib`, but that's not as easy to setup.


Copying files
-------------

To copy files to the VM: `vagrant scp file_on_host.txt :file_on_vm.txt`

To copy files from the VM: `vagrant scp :file_on_vm.txt file_on_host.txt`

Other notes
-----------

Port 2200 on the host machine should be forwarded to port 22 on the guest virtual machine.

The automation and configuration management assumes that VirtualBox will assign the IP address `10.0.2.15` to the Gitian host Vagrant VM.
