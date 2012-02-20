On the Ubuntu cloud VM:
* `apt-get -y install bridge-utils uml-utilities`
* Edit `/etc/ssh/sshd_config` to add "PermitTunnel=yes".  Make sure "PermitRootLogin=yes" too.
* Edit `/root/.ssh/authorized_keys` and remove the restrictions that prevent `root` from logging in with the `ubuntu` key. That is, delete everything until the `ssh-rsa` portion of the line.
* Run the `scripts/ubuntu-interfaces` from this directory, and paste the output into `/etc/network/interfaces`
* `/etc/init.d/networking restart` and make sure `signpost0` exists and no errors showed up on the restart.
* Reboot the VM, just to make sure all good.
