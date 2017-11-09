#!/bin/bash

# ROUND 1: Try making a snap out of a bare bones root

if [[ "$EUID" != "0" ]]; then
    echo "I .. AM... not g.. ROOT"
    exit 1
fi

ROOTDIR="`pwd`/ROOT"
BASEDIR="`pwd`"
RUNTIME_DIR="$BASEDIR/runtimes"

# Bit of house keeping to ensure package managers don't jank up the rootfs
function init_root()
{
    if [[ ! -d "$ROOTDIR" ]]; then
        mkdir $ROOTDIR
    fi

    mkdir -p $ROOTDIR/run/lock
    mkdir -p $ROOTDIR/var
    ln -s ../run/lock $ROOTDIR/var/lock
    ln -s ../run $ROOTDIR/var/run
}

# Make the rootfs happy enough for snapd
function snappify()
{
    mkdir -p $ROOTDIR/var/lib/snapd
    mkdir -p $ROOTDIR/var/log
    mkdir -p $ROOTDIR/var/snap
    mkdir -p $ROOTDIR/lib/modules
    mkdir -p $ROOTDIR/usr/src
    mkdir -p $ROOTDIR/media

    # UGLY HACKS: Get this fixed in snapd confinement policy!
    # We use lib64, snapd defines "lib" within the target
    rm $ROOTDIR/lib
    mv $ROOTDIR/lib64 $ROOTDIR/lib
    ln -sv lib $ROOTDIR/lib64
}

# Desparately attempt to install a package
function install_package()
{
    eopkg install -y -D "$ROOTDIR" --ignore-comar $*
}

# Similar to install_package, just uses -c notation.
function install_component()
{
    install_package -c $*
}

# Ugly, add a repo to the directory
function add_repo()
{
    eopkg add-repo -D "$ROOTDIR" "Solus" $1
}

function configure_pending()
{
    echo "NOT YET IMPLEMENTED :O"
}

function clean_root()
{
    # Nuke system files that take up space we're not wanting to use..
    rm -rf "$ROOTDIR/usr/share/doc"
    rm -rf "$ROOTDIR/usr/share/man"
    rm -rf "$ROOTDIR/usr/share/info"

    # Clean out package manager noise
    rm -rf "$ROOTDIR/var/lib/eopkg"
    rm -rf "$ROOTDIR/var/cache/eopkg"

    # Clean out dbs+cruft
    rm -rf "$ROOTDIR/var/db"
    rm -rf "$ROOTDIR/var/log"

    # Nuke locale archive from glibc
    rm -rf "$ROOTDIR/usr/lib64/locale"

    # Consider nuking system locales!
    # rm -rf "$ROOTDIR/usr/share/locale"
}

# Cheap and dirty, copy the named runtime meta into the root and tell it to
# bake a snap for us
function cook_snap()
{
    cp -Rv $RUNTIME_DIR/$1/meta "$ROOTDIR/."
    snap pack "$ROOTDIR"
}


# Bring up the root tree
init_root

# Let's get a repo going.
add_repo "https://packages.solus-project.com/unstable/eopkg-index.xml.xz"

# Must have our baselayout first.
install_package baselayout --ignore-safety

# Now lets fire in our core component, i.e. a working system.
# Totally ignore system.base safety to minimise the system
install_package --ignore-safety $(cat packages)

# TODO: Lock the root, configure it

# Now lets clean the rootfs out
clean_root

# Make snapd happy
snappify

# Now lets cook a snap
cook_snap gaming
