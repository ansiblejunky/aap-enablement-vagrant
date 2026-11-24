# Both boxes must be imported before running the demo; see docs/boxes.md.
if RUBY_PLATFORM.include?("darwin")
  ENV["OBJC_DISABLE_INITIALIZE_FORK_SAFETY"] ||= "YES"
  ENV["no_proxy"] ||= "*"
end

Vagrant.configure("2") do |config|
  # SSH/WinRM uploads need no shared folder support.
  config.vm.synced_folder ".", "/vagrant", disabled: true
  config.vm.box_check_update = false

  config.vm.define "linux", primary: true do |linux|
    linux.vm.box = ENV.fetch("RHEL_BOX", "demo/rhel10")
    linux.vm.hostname = "rhel-demo"
    linux.vm.network "forwarded_port", guest: 22, host: 2222,
                     host_ip: "127.0.0.1", id: "ssh", auto_correct: true
    linux.vm.network "forwarded_port", guest: 80,
                     host: Integer(ENV.fetch("RHEL_HTTP_PORT", "8080")),
                     host_ip: "127.0.0.1", id: "http"
    linux.vm.provider "virtualbox" do |vb|
      vb.memory = 2048
      vb.cpus = 2
    end
  end

  config.vm.define "windows" do |windows|
    windows.vm.box = ENV.fetch("WINDOWS_BOX", "demo/windows2022")
    windows.vm.hostname = "win-demo"
    windows.vm.guest = :windows
    windows.vm.communicator = :winrm
    windows.vm.boot_timeout = 1200
    windows.winrm.username = ENV.fetch("WINDOWS_USER", "vagrant")
    windows.winrm.password = ENV.fetch("WINDOWS_PASSWORD", "vagrant")
    windows.winrm.transport = :negotiate
    windows.winrm.guest_port = 5985
    windows.vm.network "forwarded_port", guest: 5985, host: 55985,
                       host_ip: "127.0.0.1", id: "winrm", auto_correct: true
    # Override common box defaults so management ports stay on loopback.
    windows.vm.network "forwarded_port", guest: 5986, host: 55986,
                       host_ip: "127.0.0.1", id: "winrm-ssl", disabled: true
    windows.vm.network "forwarded_port", guest: 3389, host: 53389,
                       host_ip: "127.0.0.1", id: "rdp", disabled: true
    windows.vm.network "forwarded_port", guest: 22, host: 2223,
                       host_ip: "127.0.0.1", id: "ssh", disabled: true
    windows.vm.network "forwarded_port", guest: 80,
                       host: Integer(ENV.fetch("WINDOWS_HTTP_PORT", "8081")),
                       host_ip: "127.0.0.1", id: "http"
    windows.vm.provider "virtualbox" do |vb|
      vb.memory = 4096
      vb.cpus = 2
      vb.gui = false
    end
    # Diagnostic only: WinRM must already work in the base box.
    windows.vm.provision "shell", path: "provision.ps1"
  end

  # Vagrant limits each invocation to the machine being provisioned and generates
  # the real SSH key, credentials, and forwarded ports, including corrected ports.
  config.vm.provision "ansible" do |ansible|
    ansible.playbook = "test.yml"
    ansible.compatibility_mode = "2.0"
    ansible.host_vars = {
      "linux" => { "ansible_python_interpreter" => "/usr/bin/python3" },
      "windows" => {
        "ansible_winrm_transport" => "ntlm",
        "ansible_winrm_scheme" => "http",
        "ansible_winrm_message_encryption" => "always"
      }
    }
  end
end
