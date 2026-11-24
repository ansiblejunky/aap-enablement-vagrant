# Prepare the demo boxes

Prepare images before the workshop; downloads and Windows builds can take a long
time. This repository contains configuration, not OS images or subscriptions.
Both boxes must use the **VirtualBox provider** and the host's architecture.
The complete demo requires x86-64.

The Vagrantfile defaults to local aliases so it does not depend on the lifetime
of a third-party catalog. HashiCorp documents the retirement of HCP Vagrant's
registry at the end of 2026; keep approved boxes in storage you control.
See [Vagrant box documentation](https://developer.hashicorp.com/vagrant/docs/boxes).

## RHEL 10

Use real Red Hat Enterprise Linux 10.x with accessible BaseOS and AppStream
content. CentOS, Rocky, and AlmaLinux do not satisfy this demo's RHEL assertion.

Red Hat documents building a VirtualBox-compatible Vagrant box with
[RHEL Image Builder](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/composing_a_customized_rhel_system_image/creating-vagrant-boxes-with-rhel-image-builder).
On a suitably configured, subscribed RHEL image-building system, follow that
guide to install Image Builder and prepare your blueprint. Select the current
RHEL 10 minor release available to your subscription. The documented command
shape is:

```bash
# On the RHEL image-building system; substitute an available RHEL 10 distro ID.
sudo image-builder build --distro <rhel-10-distro-id> vagrant-virtualbox
```

For example, the documentation uses `rhel-10.0` as a distro ID; use a newer
available 10.x release for an up-to-date workshop. This is a separate image
creation step, not a command to run on a macOS demo host. Follow the builder's
output for the resulting `.box` path and transfer it to the demo host.

The image must provide:

- A bootable, fully installed RHEL 10 guest for VirtualBox.
- A `vagrant` user with working Vagrant SSH key authentication and passwordless
  sudo. Image Builder's Vagrant format supplies a sudo-capable Vagrant user;
  verify key authentication before sharing the box with attendees.
- Python 3 at `/usr/bin/python3`, or repository access to install it manually
  before the first Ansible run.
- Working DHCP/NAT networking and SSH permitted through the guest firewall.
- SELinux left enabled; this lab writes into Apache's standard document root.

Import the resulting file on the demo host:

```bash
vagrant box add --name demo/rhel10 --provider virtualbox /absolute/path/to/rhel10.box
```

An approved internally built box satisfying this contract works too. Do not
embed personal subscription credentials or reusable registration identity in a
redistributable image. Register each guest after boot as shown in the README.

## Windows Server

The baseline is Windows Server 2022 x64; a Windows Server 2025 VirtualBox box
with the same connection contract also works. Use an approved internal image
or build an evaluation box from Microsoft's installation media, subject to
[Microsoft's evaluation terms](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2022).

One available build recipe is
[jborean93/packer-windoze](https://github.com/jborean93/packer-windoze).
Despite its name, it currently uses Ansible, and its inventory includes Windows
Server 2022 with a VirtualBox backend. Follow its setup instructions in a
**separate checkout and Python environment**, review the code and image sources,
and build the 2022 target with its documented platform option:

```bash
# In the prepared packer-windoze checkout, not in this repository:
ansible-playbook main.yml --limit '*2022' -e platform=virtualbox
```

Use the resulting VirtualBox `.box` file from that build's output. This is an
external image build recipe, not a box built or tested by this repository.
For Windows Server 2025, supply your organization's approved VirtualBox box;
the linked recipe's 2022 target does not build 2025.

The Windows box must already provide:

- Local administrator `vagrant` / `vagrant`, or credentials supplied through
  `WINDOWS_USER` and `WINDOWS_PASSWORD`.
- Windows PowerShell 5.1 and .NET available for Ansible Windows modules.
- WinRM running automatically with an HTTP listener on guest port 5985,
  Negotiate/NTLM authentication enabled, and a guest firewall rule allowing
  the NAT connection. Local-account remote administrative access must work.
- Working VirtualBox drivers, DHCP/NAT, and available IIS feature payloads.
- Completed installation/sysprep and no pending first-logon prompts.

The box must permit NTLM message encryption. This lab does not require Basic
authentication or `AllowUnencrypted=true`. The host-side diagnostic script
cannot fix a box that is unreachable over WinRM.
See [Ansible's Windows remoting setup](https://docs.ansible.com/projects/ansible/latest/os_guide/windows_winrm.html).

Import it:

```bash
vagrant box add --name demo/windows2022 --provider virtualbox /absolute/path/to/windows2022.box
vagrant box list
```

For a 2025 image, give it a descriptive local alias and select it explicitly:

```bash
vagrant box add --name demo/windows2025 --provider virtualbox /absolute/path/to/windows2025.box
export WINDOWS_BOX=demo/windows2025
```

Retain that export for subsequent Vagrant commands. Evaluation images expire;
rebuild or license them according to their terms before presenting.

## Workshop preparation checklist

- Record OS release, box source, provider, architecture, and SHA-256 checksum
  (`sha256sum file.box` on Linux or `shasum -a 256 file.box` on macOS).
- Import both boxes under the aliases used by the Vagrantfile.
- Check that box-level Vagrantfiles do not add bridged adapters or unexpected
  port forwards; the lab assumes NAT-only networking.
- Follow the README from first boot through registration and provisioning.
- Confirm both pages from the host and confirm a second provisioning run makes
  no Ansible changes.
- Test drift repair and cleanup before distributing the material.
