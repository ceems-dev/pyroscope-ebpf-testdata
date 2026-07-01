# pyroscope-ebpf-testdata

## Prerequisites

Docker/Podman must be installed on the host. To build multiarch images, following
packages must be installed on a Debian variant:

```bash
sudo apt-get install binfmt-support qemu-user-static
```

## Usage

## Building Python libraries

To check for new versions of python run

```bash
build_python.sh -c
```

To get a new versions of python run

```bash
build_python.sh
```

The script requires [asdf](https://asdf-vm.com/) to check for current Python versions.
If the script is not installed, it can be installed using

```bash
build_python.sh -i
```
