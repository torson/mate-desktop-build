This builds many mate-* packages from upstream Github repos for Ubuntu 20.04 Focal using Docker.

It builds from branch `master` for all repos.
You can also specify the branch in the script per package under `# setting custom branches for specific repos`

The procedure of rebuilding the package with the latest updates constists of 4 steps:
1. clone the repo with package content (A) (https://github.com/mate-desktop/mate-screensaver)
2. clone the repo package meta content / debian folder (B) (https://salsa.debian.org/debian-mate-team/mate-screensaver.git)
3. copy the debian folder (B) with cleared `patches` folder to (A) .
4. update the `debian/changelog` with the new version and rebuild the package with `dpkg-buildpackage`


Mate repositories used:
https://github.com/orgs/mate-desktop/repositories


`debian` folder (inside deb package) repositories used:
https://salsa.debian.org/debian-mate-team/


There exists https://github.com/mate-desktop/debian-packages that contains debian folders for all packages, but is outdated and causes build errors. That's why we're using the ones from https://salsa.debian.org/debian-mate-team which are being updated.

Packages that are being built are set inside envvar `MATE_PACKAGES`.
Modify the content of the list to suit your needs, maybe you need just a single package be upgraded.

# Steps

### 1. Start and get into the Ubuntu 20.04 Focal container.
This will mount the current path. All files are going to be created inside folder `build`, the deb packages will be available inside `build/00-mate-deb-packages` folder together with `install.sh`.
With using `--rm` the container and all it's content (but not the mounted current path) will be removed after you exit.

```
docker run --rm -it -v $(pwd):/mount -w /mount ubuntu:focal
```

### 2. Inside the container run:

```
./build.sh
```

At the end it outputs the command to run in a new terminal outside the container to install the packages.


### 3. In a new terminal on your host:

If you're using btrfs you should first create a snapshot of both system and home volume,  just in case something breaks.

Run the command from previous step and one to fix dependency issues:

```
cd build/00-mate-deb-packages
sudo bash install.sh

# fix dependency issues
sudo apt-get -f install
```

In case of issues revert the package that is causing the issue. For `mate-indicator-applet` that would be (check for the latest working package version with `apt-cache policy mate-indicator-applet`) :

```
apt-get install mate-indicator-applet=1.26.0-0ubuntu1~focal2.3 mate-indicator-applet-common=1.26.0-0ubuntu1~focal2.3
```

# Issues

A couple packages are not in the build list `MATE_PACKAGES` due to issues as of May 29th 2022 :

- `atril` ; error during build : dpkg-gensymbols: error: some symbols or patterns disappeared in the symbols file: see diff output below
- `mate-indicator-applet` ; the package builds ok but then after reboot the indicator applet is showing text `No indicators`
