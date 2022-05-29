#!/bin/bash
set -e

### dpkg -l | grep mate | grep 1.26 | awk '{print $2}' | grep -v -- -common | sed -r 's/:[^:]+$//'
# - we're interested in non "-common" package names only , the build procedure will create them - common, non-common one and some others
# - we're rebuilding only "mate-*" packages
# - we're stripping :amd64 from the name

## not updating directly (some are being built as part of the below packages)
# gir1.2-matedesktop-2.0:amd64
# gir1.2-matemenu-2.0:amd64
# gir1.2-matepanelapplet-4.0:amd64
# libmate-desktop-2-17:amd64
# libmate-menu2:amd64
# libmate-panel-applet-4-1:amd64
# libmate-sensors-applet-plugin0
# libmate-slab0:amd64
# libmate-window-settings1:amd64
# libmatedict6
# libmatekbd-common
# libmatekbd4:amd64
# libmatemixer-common
# libmatemixer0:amd64
# libmateweather-common
# libmateweather1:amd64
# mate-icon-theme
# ubuntu-mate-core
# ubuntu-mate-desktop

## not updating due to conflicting package debian-mate-default-settings, not sure what to do with this
# mate-session-manager

## not updating due to issues after install
# mate-indicator-applet         # indicator is showing "No indicators"

## not updating due to error
# atril       # dpkg-gensymbols: error: some symbols or patterns disappeared in the symbols file: see diff output below


# these are names of the Github repos, which are also the same as the names of deb packages
MATE_PACKAGES="
eom
libmatemixer
libmateweather
marco
mate-applets
mate-calc
mate-control-center
mate-desktop
mate-media
mate-menus
mate-netbook
mate-notification-daemon
mate-panel
mate-polkit
mate-power-manager
mate-screensaver
mate-sensors-applet
mate-settings-daemon
mate-system-monitor
mate-terminal
mate-user-guide
mate-utils
pluma
"

# need to ignore installing some packages because we're using package meta repo from debian
IGNORE_INSTALLING_PACKAGES="
debian-mate-default-settings
"

# set the base version of the packages ; reusing the latest tag (1.26.1)
# later on we're adding the branch name that's being used (default is master in all the repos) together with the latest commit hash
VER="1.26.1"
DEFAULT_BRANCH=master

RESULTING_PACKAGES_FOLDER=00-mate-deb-packages

INSTALL_MATE_DEV_PACKAGES_ALSO=false

[ -d build ] || mkdir build
cd build

### extra commands for specific packages
# removing dependency for mate-submodules-source as it's there for no reason since the repo has submodule configured to be fetched and used
echo "git submodule update --init --recursive
sed -i -r '/mate-submodules-source/d' debian/control
sed -i -r 's/; tar xvJf \/usr\/src\/mate-submodules-source.tar.xz//' debian/rules" > tmp-atril.pre-dpkg-buildpackage.sh
# for some reason ltmain.sh gets copied into the CWD of where the script is getting run
echo "ln -s ../../../ltmain.sh" > tmp-mate-applets.pre-dpkg-buildpackage.sh
echo "ln -s ../../../ltmain.sh" > tmp-mate-control-center.pre-dpkg-buildpackage.sh
# package name changed after 20.04
echo "sed -i -r 's/libgdk-pixbuf-2.0-dev/libgdk-pixbuf2.0-dev/' debian/control" > tmp-mate-desktop.pre-dpkg-buildpackage.sh
# dependencies are not fully met
echo "apt-get install -y libayatana-ido3-dev libayatana-indicator3-dev
ln -s ../../../ltmain.sh" > tmp-mate-indicator-applet.pre-dpkg-buildpackage.sh
echo "ln -s ../../../ltmain.sh" > tmp-mate-menus.pre-dpkg-buildpackage.sh
echo "ln -s ../../../ltmain.sh" > tmp-mate-netbook.pre-dpkg-buildpackage.sh
echo "ln -s ../../../ltmain.sh" > tmp-mate-notification-daemon.pre-dpkg-buildpackage.sh
echo "git submodule update --init --recursive
sed -i -r '/mate-submodules-source/d' debian/control
sed -i -r 's/; tar xvJf \/usr\/src\/mate-submodules-source.tar.xz//' debian/rules
ln -s ../../../ltmain.sh" > tmp-mate-panel.pre-dpkg-buildpackage.sh
echo "ln -s ../../../ltmain.sh" > tmp-mate-polkit.pre-dpkg-buildpackage.sh
echo "ln -s ../../../ltmain.sh" > tmp-mate-power-manager.pre-dpkg-buildpackage.sh
echo "ln -s ../../../ltmain.sh" > tmp-mate-screensaver.pre-dpkg-buildpackage.sh
echo "ln -s ../../../ltmain.sh" > tmp-mate-sensors-applet.pre-dpkg-buildpackage.sh
echo "git submodule update --init --recursive
sed -i -r '/mate-submodules-source/d' debian/control
sed -i -r 's/; tar xvJf \/usr\/src\/mate-submodules-source.tar.xz//' debian/rules
ln -s ../../../ltmain.sh" > tmp-mate-session-manager.pre-dpkg-buildpackage.sh
echo "ln -s ../../../ltmain.sh" > tmp-mate-settings-daemon.pre-dpkg-buildpackage.sh
echo "ln -s ../../../ltmain.sh" > tmp-mate-system-monitor.pre-dpkg-buildpackage.sh
echo "git submodule update --init --recursive
sed -i -r '/mate-submodules-source/d' debian/control
sed -i -r 's/; tar xvJf \/usr\/src\/mate-submodules-source.tar.xz//' debian/rules
ln -s ../../../ltmain.sh" > tmp-mate-terminal.pre-dpkg-buildpackage.sh
# there's an issue with PT translations so we're ignoring it : https://github.com/mate-desktop/mate-utils/issues/211
echo "git submodule update --init --recursive
sed -i -r '/mate-submodules-source/d' debian/control
sed -i -r 's/; tar xvJf \/usr\/src\/mate-submodules-source.tar.xz//' debian/rules
ln -s ../../../ltmain.sh
sed -i s/\"IGNORE_HELP_LINGUAS =\"/\"IGNORE_HELP_LINGUAS = pt\"/g gsearchtool/help/Makefile.am" > tmp-mate-utils.pre-dpkg-buildpackage.sh
echo "git submodule update --init --recursive
sed -i -r '/mate-submodules-source/d' debian/control
sed -i -r 's/; tar xvJf \/usr\/src\/mate-submodules-source.tar.xz//' debian/rules
ln -s ../../../ltmain.sh" > tmp-pluma.pre-dpkg-buildpackage.sh

### setting custom CPU count for specific repos
# there are some race conditions generating translations so we set number of CPUs to 1
#     https://github.com/mate-desktop/mate-utils/pull/217
#     https://github.com/mate-desktop/mate-utils/issues/211
#     https://github.com/mate-desktop/mate-utils/issues/210
echo "1" > tmp-mate-utils.dpkg-buildpackage.nproc

### setting custom branches for specific repos
## this is here just for example
# echo "1.27" > tmp-mate-utils.branch
# echo "dev" > tmp-mate-utils-debian.branch

export DEBIAN_FRONTEND=noninteractive

[ -d ${RESULTING_PACKAGES_FOLDER} ] || mkdir ${RESULTING_PACKAGES_FOLDER}

run_command() { echo -e "\n\n--> $(date) : Running: $@" ; $@ ; CMD_EXIT_CODE=$? ; if [ "$CMD_EXIT_CODE" != "0" ]; then echo -e "\n\n--> $(date) [$(basename ${0})]: ERROR (run_command): command exited with exit code $CMD_EXIT_CODE " ; return $CMD_EXIT_CODE ; fi ; }
log() { echo -e "\n--> $(date) : $1" ; }

if [ ! -f /system_prepare.done ]; then
    echo "upgrade all packages" && \
    apt-get update && \
    apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade && \
    echo "install basic packages" && \
    apt-get -y install \
            ca-certificates \
            less \
            lsb-release \
            openssl \
            software-properties-common \
            vim-tiny \
            tzdata \
            curl \
            checkinstall

    apt-get install -y build-essential make automake dh-make git
    # dependencies for dpkg-buildpackage
    apt-get install -y debhelper=13.5.2ubuntu1~bpo20.04.1 libdebhelper-perl=13.5.2ubuntu1~bpo20.04.1

    add-apt-repository -y ppa:ubuntu-mate-dev/fresh-mate
    # enable sources for mate packages
    sed -i -r 's/^# //' /etc/apt/sources.list.d/ubuntu-mate-dev-ubuntu-fresh-mate-focal.list

    apt update

    touch /system_prepare.done
fi

# rebuilding mate packages

# fetching repo that contains debian folders for all packages
# > not using it as it's outdated and causes build errors, we're using debian packages which are being updated
# if [ ! -d mate-debian-packages ]; then
#     run_command git clone https://github.com/mate-desktop/debian-packages mate-debian-packages
# fi

## not needed really as repos have this submodule set up, one just needs to tweak them a bit to use it
# mate-panel depends on package mate-submodules-source so we need to first build this one
#   dpkg-checkbuilddeps: error: Unmet build dependencies: mate-submodules-source (>= 0.0~git20210623.f3091f9)
# if ! dpkg -l | grep mate-submodules-source ; then
#     git clone https://github.com/mate-desktop/mate-submodules.git
#     cd mate-submodules

#     ln -s ../ltmain.sh

#     # running stuff gotten from mate-submodules/.build.yml
#     # first required packages (cppcheck is not there in the list but is required)
#     apt-get install -y autoconf-archive autopoint clang clang-tools gcc git libglib2.0-dev libgtk-3-dev make mate-common meson cppcheck

#     # setting DISTRO_NAME=debian as that's what the build code is leaning on. We just reuse the whole code so if it updates in the
#     # future we can just copy/paste it
#     DISTRO_NAME=debian
#     CPU_COUNT=4
#     CHECKERS="-enable-checker deadcode.DeadStores -enable-checker alpha.deadcode.UnreachableCode -enable-checker alpha.core.CastSize -enable-checker alpha.core.CastToStruct -enable-checker alpha.core.IdenticalExpr -enable-checker alpha.core.SizeofPtr -enable-checker alpha.security.ArrayBoundV2 -enable-checker alpha.security.MallocOverflow -enable-checker alpha.security.ReturnPtrRange -enable-checker alpha.unix.SimpleStream -enable-checker alpha.unix.cstring.BufferOverlap -enable-checker alpha.unix.cstring.NotNullTerminated -enable-checker alpha.unix.cstring.OutOfBounds -enable-checker alpha.core.FixedAddr -enable-checker security.insecureAPI.strcpy"

#     # build code from mate-submodules/.build.yml START
#     if [ ${DISTRO_NAME} == "debian" ];then
#         export CFLAGS+=" -Wsign-compare"
#         cppcheck --enable=warning,style,performance,portability,information,missingInclude .
#     fi
#     autoreconf -fi
#     scan-build $CHECKERS ./configure --enable-compile-warnings=maximum
#     if [ $CPU_COUNT -gt 1 ]; then
#         if [ ${DISTRO_NAME} == "debian" ];then
#             scan-build $CHECKERS --keep-cc --use-cc=clang --use-c++=clang++ -o html-report make -j $(( $CPU_COUNT + 1 ))
#             make clean
#         fi
#         scan-build $CHECKERS --keep-cc -o html-report make -j $(( $CPU_COUNT + 1 ))
#     else
#         if [ ${DISTRO_NAME} == "debian" ];then
#             scan-build $CHECKERS --keep-cc --use-cc=clang --use-c++=clang++ -o html-report make
#             make clean
#         fi
#         scan-build $CHECKERS --keep-cc -o html-report make
#     fi
#     # build code from mate-submodules/.build.yml END

#     # create package and install it
#     checkinstall -y --install=yes --pkgname=mate-submodules-source --pkgversion=0.0~git$(date "+%Y%m%d") --pkggroup=Application/Accessories
# fi

for PKG in $(echo "${MATE_PACKAGES}"); do
    # setting CPU_COUNT to max, as we could have set it to 1 for specific packages due to race condition errors
    CPU_COUNT=$(nproc)

    echo ; echo "###" ; echo "### ${PKG}" ; echo "###" ; echo
    run_command apt-get build-dep -y ${PKG}

    [ -d ${PKG} ] || mkdir ${PKG}
    cd ${PKG}
    # > at build/PKG level

    # in the output of `apt-get source mate-screensaver` (all mate-* packages) it says:
    #    NOTICE: 'mate-screensaver' packaging is maintained in the 'Git' version control system at:
    #    https://salsa.debian.org/debian-mate-team/mate-screensaver.git
    #    Please use:
    #    git clone https://salsa.debian.org/debian-mate-team/mate-screensaver.git
    #    to retrieve the latest (possibly unreleased) updates to the package.
    # ; in that repo there's the updated content of mate-screensaver_1.26.0-0ubuntu1~focal2.0.debian.tar.xz that contains
    # the debian folder of the package (mate-screensaver-1.26.0/debian) that got created with `apt-get source mate-screensaver`

    ## 4 steps in rebuilding the package with the latest updates
    # 1. clone the package content (A) (https://github.com/mate-desktop/mate-screensaver)
    # 2. clone the package meta content (B) (https://salsa.debian.org/debian-mate-team/mate-screensaver.git)
    # 3. copy the debian folder (B) to (A) .
    # 4. rebuild the package

    ## checking for presence of the repo
    log "checking for repo: https://github.com/mate-desktop/${PKG}"
    if ! curl -I https://github.com/mate-desktop/${PKG} | grep "HTTP/2 200" ; then
        log "https://github.com/mate-desktop/${PKG} does not exist , exiting..."
        exit 1
    fi

    ## debian/ folder for all packages is contained in repos at https://salsa.debian.org/debian-mate-team/
    #  there is a repo https://github.com/mate-desktop/debian-packages but the debian.org ones are being updated
    log "checking for repo: https://salsa.debian.org/debian-mate-team/${PKG}"
    if ! curl -I https://salsa.debian.org/debian-mate-team/${PKG} | grep "HTTP/2 200" ; then
        log "https://salsa.debian.org/debian-mate-team/${PKG} does not exist , exiting..."
        exit 1
    fi

    if [ -d ${PKG} ]; then rm -Rf ${PKG} ; fi
    run_command git clone https://github.com/mate-desktop/${PKG}

    # setting correct branch/tag
    cd ${PKG}
    BRANCH=${DEFAULT_BRANCH}
    if [ -f ../../tmp-${PKG}.branch ]; then
        echo "using ../../tmp-${PKG}.branch"
        run_command cat ../../tmp-${PKG}.branch
        BRANCH=$(cat ../../tmp-${PKG}.branch)
    fi
    run_command git checkout ${BRANCH}
    cd ..

    ## these actually have patches inside which is not ok for us since we're building from latest upstream
    #  so we're clearing the patches folder
    if [ -d ${PKG}-debian ]; then rm -Rf ${PKG}-debian ; fi
    run_command git clone https://salsa.debian.org/debian-mate-team/${PKG} ${PKG}-debian

    # setting correct branch/tag
    cd ${PKG}-debian
    BRANCH=${DEFAULT_BRANCH}
    if [ -f ../../tmp-${PKG}-debian.branch ]; then
        echo "using ../../tmp-${PKG}-debian.branch"
        run_command cat ../../tmp-${PKG}-debian.branch
        BRANCH=$(cat ../../tmp-${PKG}-debian.branch)
    fi
    run_command git checkout ${BRANCH}
    cd ..

    # a) using mate-debian-packages
    #    > these are actualy not ok because packages file set has differed, this repo is not kept up to date and so the build process fails due to inconsistent file listing for some packages.
    #    > salsa.debian.org repos are being updated
    # cp -R ../mate-debian-packages/${PKG}/debian ${PKG}/

    # b) using salsa.debian.org
    #    > clearing patches folder
    if [ -d ${PKG}-debian/debian/patches ]; then run_command rm -Rf ${PKG}-debian/debian/patches ; fi
    # clearing debian folder in case we're iterating tests
    if [ -d ${PKG}/debian ]; then run_command rm -Rf ${PKG}/debian ; fi
    run_command cp -R ${PKG}-debian/debian ${PKG}/

    cd ${PKG}
    # > at build/PKG/PKG level

    BRANCH=$(git rev-parse --abbrev-ref HEAD)
    COMMIT_HASH=$(git rev-parse HEAD | cut -c1-6)
    VER_FULL="${VER}~${BRANCH}-${COMMIT_HASH}-focal-1"
    echo ; echo "### using branch: ${BRANCH} , latest commit ${COMMIT_HASH}" ; echo

    # adding version to debian/changelog , dpkg-buildpackage uses this to set the package version
    echo "${PKG} (${VER_FULL}) unstable; urgency=medium

  * Used master branch.

 -- No Name <noname@local.domain>  $(date -R)
" | cat - debian/changelog > temp && mv temp debian/changelog

    if [ -f ../../tmp-${PKG}.pre-dpkg-buildpackage.sh ]; then
        echo "running script ../../tmp-${PKG}.pre-dpkg-buildpackage.sh"
        run_command cat ../../tmp-${PKG}.pre-dpkg-buildpackage.sh
        run_command bash ../../tmp-${PKG}.pre-dpkg-buildpackage.sh
    fi

    # setting CPU count for dpkg-buildpackage due to race conditions
    if [ -f ../../tmp-${PKG}.dpkg-buildpackage.nproc ]; then
        echo "using ../../tmp-${PKG}.dpkg-buildpackage.nproc"
        run_command cat ../../tmp-${PKG}.dpkg-buildpackage.nproc
        CPU_COUNT=$(cat ../../tmp-${PKG}.dpkg-buildpackage.nproc)
    fi

    # -us  - do not sign the source package
    # -uc  - do not sign the .changes file
    # -b   - binary-only build, no sources
    # -j4  - number of parallel jobs (just in case)
    run_command dpkg-buildpackage -us -uc -b -j${CPU_COUNT}

    cd ..
    # > at build/PKG level

    # copy created .deb files to a single target folder and add package install command to the final install.sh script
    echo "## ${PKG}" >> ../${RESULTING_PACKAGES_FOLDER}/install.sh
    for DPKG in *.deb ; do
        run_command cp ${DPKG} ../${RESULTING_PACKAGES_FOLDER}/

        IGNORE_PKG=false
        for IGNORE_PKG_NAME in $(echo "${IGNORE_INSTALLING_PACKAGES}"); do
            if echo ${DPKG} | grep -- "${IGNORE_PKG_NAME}" ; then
                log "commenting out ${DPKG} in install.sh"
                IGNORE_PKG=true
            fi
        done
        if echo ${DPKG} | grep -- "-dev_" ; then
            if [ "${INSTALL_MATE_DEV_PACKAGES_ALSO}" != "true" ]; then
                log "commenting out ${DPKG} in install.sh"
                IGNORE_PKG=true
            fi
        fi

        if [ "${IGNORE_PKG}" = "true" ]; then
            echo "# dpkg -i ${DPKG}" >> ../${RESULTING_PACKAGES_FOLDER}/install.sh
        else
            echo "dpkg -i ${DPKG}" >> ../${RESULTING_PACKAGES_FOLDER}/install.sh
        fi
    done
    echo >> ../${RESULTING_PACKAGES_FOLDER}/install.sh

    cd ..
    # > at build/ level

done

cd ..
# > at script level

echo "#########################" ; echo
log "Packages build process finished. Inspect and run file ${RESULTING_PACKAGES_FOLDER}/install.sh :"
echo "                                         cd ${RESULTING_PACKAGES_FOLDER} ; ./install.sh "

# removing leftover ltmain.sh
if [ -f ltmain.sh ]; then rm ltmain.sh ; fi

# removing tmp files
rm build/tmp-*
