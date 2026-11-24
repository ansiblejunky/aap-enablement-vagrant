# Local RHEL and Windows provisioning with Vagrant

This lab teaches how HashiCorp Vagrant creates two local VMs and calls Ansible
on the host to configure them. You will install web servers, publish the same
template on both operating systems, verify the results, and repair configuration
drift.

| Vagrant machine | Guest | Ansible connection | Demo |
| --- | --- | --- | --- |
| `linux` | RHEL 10.x | SSH, Python 3, sudo | Apache at http://127.0.0.1:8080/ |
| `windows` | Windows Server 2022 (2025 also accepted) | WinRM, PowerShell | IIS at http://127.0.0.1:8081/index.html |

Vagrant manages VM lifecycle and connection details. Ansible manages packages,
files, firewall rules, and services **inside the guests**. The playbook never
uses `connection: local`.

## Prerequisites

- An **x86-64 Linux host or Intel Mac**, with hardware virtualization enabled.
  Allow at least 6 GiB RAM for the guests; 16 GiB host RAM and 60 GiB free disk
  are useful starting points. Building boxes needs more disk and time.
- Vagrant 2.4.9 or newer and a VirtualBox release supported by your Vagrant
  version and host. Other providers require matching boxes and configuration;
  they are outside this walkthrough.
- Python 3.11+ and OpenSSH on the host. Run Vagrant and Ansible from the same
  terminal with the Python environment activated.
- Two prepared VirtualBox boxes: real RHEL 10 and Windows Server 2022 or newer.
  **Prepare/import these first using [the box guide](docs/boxes.md).**
  The default names `demo/rhel10` and `demo/windows2022` are local aliases,
  not public downloads.
- RHEL repository access through your Red Hat subscription, Developer
  subscription if eligible, or an approved Satellite/content source. Windows
  requires a valid license or evaluation entitlement.

**Apple Silicon:** this complete VirtualBox demo cannot run on an ARM Mac:
Windows Server requires x64 and VirtualBox does not run x86 guests on ARM.
Use an x86-64 host for both machines. A matching ARM64 RHEL box can be used for
a Linux-only experiment, but that does not validate the Windows half.
See [Microsoft's requirements](https://learn.microsoft.com/en-us/windows-server/get-started/hardware-requirements)
and [VirtualBox's architecture limits](https://download.virtualbox.org/virtualbox/7.2.8/UserManual.pdf).
Native Windows is not the Ansible controller used here; WSL/provider integration
is outside this walkthrough.

## Set up the controller

From the repository root:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
ansible-galaxy collection install -r requirements.yml
vagrant --version
ansible-playbook --version
vagrant box list
```

The dependencies keep ansible-core on the 2.19 release line and declare the
Windows and firewall collections explicitly. These are compatibility ranges,
not a fully locked environment. Record the resolved versions and box checksums
when preparing a repeatable workshop.

On macOS, also set these for direct Ansible commands
([Ansible's WinRM guidance](https://docs.ansible.com/projects/ansible/latest/os_guide/windows_winrm.html)):

```bash
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
export no_proxy='*'
```

The Vagrantfile supplies these defaults to its own child processes on macOS.
The proxy bypass applies to this lab terminal; use a Linux controller if your
environment requires a proxy configuration incompatible with it.

## Run the demo

1. Validate configuration without starting any VMs:

   ```bash
   ruby -c Vagrantfile
   vagrant validate
   yamllint test.yml requirements.yml
   ansible-playbook -i 'linux,windows,' test.yml --syntax-check
   ```

2. Boot RHEL without provisioning, then prepare repository access:

   ```bash
   vagrant up linux --provider=virtualbox --no-provision
   vagrant ssh linux
   ```

   Inside the guest, if your box is not already configured for content access:

   ```bash
   sudo subscription-manager register
   sudo dnf repolist
   sudo dnf install -y python3
   exit
   ```

   Registration prompts for credentials rather than storing them in the repo.
   Use your organization's registration procedure for Satellite or activation
   keys. Confirm BaseOS and AppStream content is available before proceeding.

3. Provision RHEL, then boot and provision Windows:

   ```bash
   vagrant provision linux
   vagrant up windows --provider=virtualbox
   vagrant status
   ```

   Allow extra time for the first Windows boot and IIS feature installation.
   Each invocation runs the common playbook limited to that guest. The other
   guest's play may show a normal skip. Once both boxes and RHEL repository
   access are prepared, `vagrant up --provider=virtualbox` brings up both and
   provisions any newly created machines. For already running machines use
   `vagrant provision` or `vagrant up --provision`.

4. Verify from the host or open the URLs in a browser:

   ```bash
   curl --fail http://127.0.0.1:8080/
   curl --fail http://127.0.0.1:8081/index.html
   ```

   Expect `Provisioned by Ansible on linux` and
   `Provisioned by Ansible on windows`, plus OS information.
   Each play also asserts the guest OS and checks its HTTP response internally.

## Show desired state and drift repair

Reapply the configuration:

```bash
vagrant provision
```

After a successful first run, Ansible should report `changed=0` for each guest.
The Windows PowerShell diagnostic provisioner prints information independently
of Ansible's recap.

The generated inventory contains the actual keys, users, and forwarded ports.
The included `ansible.cfg` selects it for direct commands:

```bash
ansible linux -m ansible.builtin.ping
ansible windows -m ansible.windows.win_ping
ansible-playbook test.yml -e 'demo_message=Hello from the workshop'
```

Refresh both pages to see the new heading. Repeating that same command should
make no changes. Running `vagrant provision` restores the default heading.

To demonstrate drift, stop the services outside Ansible:

```bash
vagrant ssh linux -c 'sudo systemctl stop httpd'
vagrant winrm windows --command 'Stop-Service W3SVC'
vagrant provision
```

Ansible starts the services again. Repeat the host `curl` checks to prove repair.
Do not use `--check` as a replacement for the first provisioning run: packages,
features, and files must exist for later tasks to work.

## Configuration and connections

| Environment variable | Default | Purpose |
| --- | --- | --- |
| `RHEL_BOX` | `demo/rhel10` | Imported RHEL 10 box name |
| `WINDOWS_BOX` | `demo/windows2022` | Imported Windows Server box name |
| `WINDOWS_USER` | `vagrant` | Box's local administrator |
| `WINDOWS_PASSWORD` | `vagrant` | Box's lab password |
| `RHEL_HTTP_PORT` | `8080` | Host port for Apache |
| `WINDOWS_HTTP_PORT` | `8081` | Host port for IIS |

Export overrides before every Vagrant invocation; changing a box requires
recreating its guest. For a port change on existing machines use
`vagrant reload`, then `vagrant provision`.

SSH and WinRM ports may auto-correct on conflicts. HTTP ports fail on conflicts
so the documented browser URLs stay predictable; override the relevant variable.
Use `vagrant port linux` and `vagrant port windows` to inspect actual mappings.

Vagrant writes inventory under
`.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory`.
Run provisioning to refresh it after recreating/reloading guests. The previous
handwritten `inventory` file was removed because fixed ports become stale.
Do not commit or share generated inventory: it includes the Windows password.

This is an isolated development lab with known box credentials. Port forwards
bind to loopback and shared folders are disabled. Windows uses NTLM with required
message encryption over HTTP, confined to the local NAT forward; see
[Ansible's WinRM encryption options](https://docs.ansible.com/projects/ansible-core/devel/collections/ansible/builtin/winrm_connection.html).
For a deployed environment use trusted HTTPS certificates and your approved
authentication policy. Review imported boxes for additional networking defaults.

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| Box lookup/download fails | Import the local aliases first; verify provider and architecture with `vagrant box list`. |
| x86 guest fails on ARM | Use the x86-64 host required for the full demo. |
| Ansible executable or collection missing | Activate `.venv` in the Vagrant terminal and install both requirements files. |
| RHEL package installation fails | Check guest DNS/network, subscription registration, and BaseOS/AppStream access using `sudo dnf repolist`. |
| Python missing during fact gathering | Install Python 3 in the RHEL guest with `sudo dnf install -y python3`. |
| Windows boot/WinRM timeout | Check the VM console, license/evaluation state, HTTP listener, firewall, and box credentials. The diagnostic script needs an already working WinRM connection. |
| Windows connection rejected | Confirm a local admin account, NTLM/Negotiate enabled, and remote administrative access configured in the box. |
| HTTP page unavailable | Check the play recap for failures and inspect `vagrant port`; the Windows URL is `/index.html`. |
| macOS Python crashes or WinRM fails | Export both macOS environment variables above in the active terminal. |

## Clean up

```bash
vagrant halt
```

This preserves the guests. Before deleting a registered RHEL guest, release its
registration using your organization's process, for example:

```bash
vagrant ssh linux -c 'sudo subscription-manager unregister'
vagrant destroy -f
```

Destroy deletes both demo VMs and their data. Imported base boxes stay cached.
Recreating RHEL requires registering its new instance again.

## Repository map and validation status

- `Vagrantfile`: machine resources, loopback forwards, Ansible invocation.
- `test.yml`: Apache and IIS provisioning, OS assertions, HTTP checks.
- `templates/index.html.j2`: shared managed page.
- `provision.ps1`: read-only Windows diagnostics.
- `docs/boxes.md`: box creation/import and image requirements.
- `requirements.txt`, `requirements.yml`, `ansible.cfg`: controller setup.

Static configuration validation was performed on an ARM64 Mac. A complete VM
run, guest provisioning, and second-run idempotence have **not** been verified
here. Before presenting, run this walkthrough on the x86-64 demo host, confirm
both host HTTP checks, rerun provisioning, and rehearse drift repair.

References: [Vagrant Ansible provisioner](https://developer.hashicorp.com/vagrant/docs/provisioning/ansible),
[Vagrant generated inventory](https://developer.hashicorp.com/vagrant/docs/provisioning/ansible_common).
