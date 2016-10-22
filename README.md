Zcash deterministic builds
==========================

This is a deterministic build environment for [Zcash](https://github.com/zcash/zcash/) that uses [Gitian](https://gitian.org/).

Gitian provides a way to be reasonably certain that the Zcash executables are really built from the exact source on GitHub and have not been tampered with. It also makes sure that the same, tested dependencies are used and statically built into the executable.

Multiple developers build from source code by following a specific descriptor ("recipe"), cryptographically sign the result, and upload the resulting signature. These results are compared and only if they match is the build is accepted.

More independent Gitian builders are needed, which is why this guide exists.

Requirements
------------

4GB of RAM, at least two cores

It relies upon [Vagrant](https://www.vagrantup.com/) and [VirtualBox](https://www.virtualbox.org/) plus [Ansible](https://www.ansible.com/).

#### VirtualBox

If you use Linux, we recommend obtaining VirtualBox through your package manager instead of the Oracle website.

    sudo apt-get install linux-headers-amd64 virtualbox

Linux kernel headers are required to setup the `/dev/vboxdrv` device and VirtualBox kernel module via `virtualbox-dkms`.

#### Vagrant

Download the latest version of Vagrant from [their website](https://www.vagrantup.com/downloads.html).

#### Ansible

Install prerequisites first: `sudo apt-get install build-essential libssl-dev libffi-dev python python-dev python-pip`. Then run:

    sudo pip install -U ansible

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

Make sure VirtualBox, Vagrant and Ansible are installed, and then run:

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

We provide two options for automatically importing keys into the VM, or you may choose to copy them manually. Keys are needed A) to sign the manifests which get pushed to [gitian.sigs](https://github.com/zcash/gitian.sigs) and B) to interact with GitHub, if you choose to use an SSH instead of HTTPS remote. The latter would entail always providing your GitHub login and access token in order to push from within the VM.

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
