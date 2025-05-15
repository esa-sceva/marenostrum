# marenostrum


## Install singularity on macOS
All info [here](https://docs.sylabs.io/guides/3.0/user-guide/installation.html#install-on-windows-or-mac)

Install virtualbox
```bash
brew install virtualbox --cask
```
Install vagrant
```bash
brew install vagrant --cask
brew install vagrant-manager --cask
```

Create and use a folder for vagrant
```bash
mkdir vm-singularity
cd vm-singularity
```

Run vagrant
```bash
export VM=sylabs/singularity-3.0-ubuntu-bionic64 && \
    vagrant init $VM && \
    vagrant up && \
    vagrant ssh
```

