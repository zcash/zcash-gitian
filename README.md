Zcash deterministic builds
==========================

This is a deterministic build environment for [Zcash](https://github.com/zcash/zcash/) that uses [Gitian](https://gitian.org/).

Gitian provides a way to be reasonably certain that the Zcash executables are really built from the exact source on GitHub and have not been tampered with. It also makes sure that the same, tested dependencies are used and statically built into the executable.

Multiple developers build from source code by following a specific descriptor ("recipe"), cryptographically sign the result, and upload the resulting signature. These results are compared and only if they match is the build accepted.

More independent Gitian builders are needed, which is why this guide exists.

Requirements
------------

4GB of RAM, at least two cores

It relies upon [Vagrant](https://www.vagrantup.com/) and [VirtualBox](https://www.virtualbox.org/) plus [Ansible](https://www.ansible.com/).

#### VirtualBox

If you use Linux, we recommend obtaining VirtualBox through your package manager instead of the Oracle website.

    sudo apt-get install virtualbox

#### Vagrant

Download the latest version of Vagrant from [their website](https://www.vagrantup.com/downloads.html).

#### Ansible

Install prerequisites first: `sudo apt-get install build-essential libssl-dev libffi-dev python python-dev python-pip`. Then run:

    sudo pip install -U ansible

#### GnuPG 2.x

Make sure GNU privacy guard is installed.

    sudo apt-get install gnupg2

If installing via some other method, such as building directly from git source or using a different
package manager, make sure it is callable using the command 'gpg2'. For instance, if it installs as
'gpg' you could create a symlink from gpg2 to gpg.


## Decide on a gpg keypair to use for gitian

You'll be asked to (optionally) refer to a gpg key in gitian.yml.

You can generate a keypair specifically for zcash gitian builds with a command like the one below.

```
gpg2 --quick-gen-key --batch --passphrase '' "Harry Potter (zcash gitian) <hpotter@hogwarts.wiz>"
gpg: directory '/Users/hpotter/.gnupg' created
gpg: keybox '/Users/hpotter/.gnupg/pubring.kbx' created
gpg: /Users/hpotter/.gnupg/trustdb.gpg: trustdb created
gpg: key 5B52696EF083A700 marked as ultimately trusted
gpg: directory '/Users/hpotter/.gnupg/openpgp-revocs.d' created
gpg: revocation certificate stored as '/Users/hpotter/.gnupg/openpgp-revocs.d/564CDA5C132B8CAB54B7BDE65B52696EF083A700.rev'
```
This will generate a primary key and subkey without passphrases, and set default values for
algorithm, key length, usage, and expiration time which should be fine.


Some explanation of the arguments used in the above example:

    --quick-generate-key --batch   This combination of options allows options to be given on the
                                   command line. Other key generation options use interative
                                   prompts.

    --passphrase ''                Passphrase for the generated key. An empty string as shown here
                                   means save the private key unencrypted.

    "Name (Comment) <Email>"       The user id (also called uid) to associate with the generated
                                   keys. Concatenating a name, an optional comment, and an email
                                   address using this format is a gpg convention.


You can check that the key was generated and added to your local gpg key database, and see its
fingerprint value, like this:
```
$ gpg2 --list-keys
/Users/hpotter/.gnupg/pubring.kbx
-----------------------------------
pub   rsa2048 2018-03-14 [SC] [expires: 2020-03-13]
      564CDA5C132B8CAB54B7BDE65B52696EF083A700
uid           [ultimate] Harry Potter (zcash gitian) <hpotter@hogwarts.wiz>
sub   rsa2048 2018-03-14 [E]
```

We'll use two values from the above output in our gitian.yml file:
- For gpg_key_id we'll use the id for the 'pub' key. In the example output shown here, that is a 40
character value. Other versions of gpg may truncate this value, e.g. to 8 or 16 characters. In those
cases you should be able to use the truncated value and it should still work.
- For gpg_key_name we'll use the the part before the @ symbol of the associated email address.

Continuing the above example, we would set the two fields in gitian.yml as follows:
```
gpg_key_id: 564CDA5C132B8CAB54B7BDE65B52696EF083A700
gpg_key_name: hpotter
```

## Decide on an ssh keypair to use for gitian

You'll be asked to (optionally) provide an ssh key's filename in gitian.yml. In this example I'm
using "zcash_gitian_id_rsa".

You can generate a keypair specifically for zcash gitian builds like this:

```
$ ssh-keygen -t rsa -C "hpotter@hogwarts.wiz" -f ~/.ssh/zcash_gitian_id_rsa -N ''
Generating public/private rsa key pair.
Your identification has been saved in /Users/hpotter/.ssh/zcash_gitian_id_rsa.
Your public key has been saved in /Users/hpotter/.ssh/zcash_gitian_id_rsa.pub.
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

    -t rsa                         Use a key type of RSA

    -C "hpotter@hogwarts.wiz"      Provide an identity to associate with the key (default is
                                   user@host in the local environment)

    -f ~/.ssh/zcash_gitian_id_rsa  Path to the private key to generate. The corresponding public key
                                   will be saved at ~/.ssh/zcash_gitian_id_rsa.pub

    -N ''                          Passphrase for the generated key. An empty string as shown here
                                   means save the private key unencrypted.


How to get started
------------------

### Edit settings in gitian.yml

```yaml
# URL of repository containing Zcash source code.
zcash_git_repo_url: 'https://github.com/zcash/zcash'

# Specific tag or branch you want to build.
zcash_version: 'master'

# The name@ in the e-mail address of your GPG key, alternatively a key ID.
gpg_key_name: ''

# Equivalent to git --config user.name & user.email
git_name: ''
git_email: ''

# OPTIONAL set to import your GPG key into the VM.
gpg_key_id: ''

# OPTIONAL set to import your SSH key into the VM. Example: id_rsa, id_ed25519. Assumed to reside in ~/.ssh
ssh_key_name: ''
```

Make sure VirtualBox, Vagrant and Ansible are installed.

Include this vagrant plugin to support resize of the start up disk:

    vagrant plugin install vagrant-disksize

Then run:

    vagrant up --provision zcash-build

This will provision a Gitian host virtual machine that uses a Linux container (LXC) guest to perform the actual builds.

Use `git stash` to save one's local customizations to `gitian.yml`.

Building Zcash
--------------

    vagrant ssh zcash-build
    ./gitian-build.sh

The output from `gbuild` is informative. There are some common warnings which can be ignored, e.g. if you get an intermittent privileges error related to LXC then just execute the script again. The most important thing is that one reaches the step which says `Running build script (log in var/build.log)`. If not, then something else is wrong and you should let us know.

Take a look at the variables near the top of `~/gitian-build.sh` and get familiar with its functioning, as it can handle most tasks.

It's also a good idea to regularly `git pull` on this repository to obtain updates and re-run the entire VM provisioning for each release, to ensure current and consistent state for your builder.

Generating and uploading signatures
-----------------------------------

After the build successfully completes, `gsign` will be called. Commit and push your signatures (both the .assert and .assert.sig files) to the [zcash/gitian.sigs](https://github.com/zcash/gitian.sigs) repository, or if that's not possible then create a pull request.

Signatures can be verified by running `gitian-build.sh --verify`, but set `build=false` in the script to skip building. Run a `git pull` beforehand on `gitian.sigs` so you have the latest. The provisioning includes a task which imports Zcash developer public keys to the Vagrant user's keyring and sets them to ultimately trusted, but they can also be found at `contrib/gitian-downloader` within the Zcash source repository.

Working with GPG and SSH
--------------------------

We provide two options for automatically importing keys into the VM, or you may choose to copy them manually. Keys are needed A) to sign the manifests which get pushed to [gitian.sigs](https://github.com/zcash/gitian.sigs) and B) to interact with GitHub, if you choose to use an SSH instead of HTTPS remote. The latter would entail always providing your GitHub login and [access token](https://github.com/settings/tokens) in order to push from within the VM.

Your local SSH agent is automatically forwarded into the VM via a configuration option. If you run ssh-agent, your keys should already be available.

GPG is trickier, especially if you use a smartcard and can't copy the secret key. We have a script intended to forward the gpg-agent socket into the VM, `forward_gpg_agent.sh`, but it is not currently working. If you want your full keyring to be available, you can use the following workaround involving `sshfs` and synced folders:

    vagrant plugin install vagrant-sshfs

Uncomment the line beginning with `gitian.vm.synced_folder "~/.gnupg"` in `Vagrantfile`. Ensure the destination mount point is empty. Then run:

    vagrant sshfs --mount zcash-build

Vagrant synced folders may also work natively with `vboxfs` if you install VirtualBox Guest Additions into the VM from `contrib`, but that's not as easy to setup.


Copying files
-------------

The easiest way to do it is with a plugin.

    vagrant plugin install vagrant-scp

To copy files to the VM: `vagrant scp file_on_host.txt :file_on_vm.txt`

To copy files from the VM: `vagrant scp :file_on_vm.txt file_on_host.txt`

Other notes
-----------

Port 2200 on the host machine should be forwarded to port 22 on the guest virtual machine.

The automation and configuration management assumes that VirtualBox will assign the IP address `10.0.2.15` to the Gitian host Vagrant VM.

Tested with Ansible 2.1.2 and Vagrant 1.8.6 on Debian GNU/Linux (jessie).
