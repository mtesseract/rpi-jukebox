<p align="center">
  <img width="300" src="./assets/ansible-pi-logo.png">
</p>

# Raspberry PI setup with Ansible

Setup your RPI from scratch with only one command!
This repository is based on [Calychas/ansible-pi.git](https://github.com/Calychas/ansible-pi.git) -- credits go out to [Calychas](Calychas).

## Description

This repository contains Ansible tasks needed to setup a Raspberry Pi as a Jukebox.

## Getting Started

### Dependencies

* Install [nix](https://nixos.org).
* Enter a nix-shell by executing `nix-shell` in this directory.
* Raspberry Pi flashed with a recent Raspberry Pi OS lite 64-bit. See [Raspberry Pi OS Imager](https://www.raspberrypi.com/software/) if you didn't install it yet.
* Raspberry Pi shall be reachable in your network with SSH login enabled.

### Preparation

Copy `inventory.yaml.example` to `inventory.yaml` and update `inventory.yaml`: change `host-name` and (if required) SSH login configuration (`ansible_user`, `ansible_password`, `ansible_port`).

### Executing

First debug the connection:

```sh
ansible-playbook -i inventory.yaml debug.yaml
```

If everything works, run the full suite:

```sh
ansible-playbook -i inventory.yaml rpi-jukebox.yaml -vv
```

## Authors

* Kacper Leśniara
* Moritz Clasmeier

## License

This project is licensed under the MIT License - see the [LICENSE.md](./LICENSE.md) file for details
