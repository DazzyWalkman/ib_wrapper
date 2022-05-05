#!/bin/bash
usage() {
    echo "$0 profile <image|clean>"
    exit 1
}
init_var() {
    profile=$1
    type=""
    ver=""
    confile="conf/main.conf"
    mirror="downloads.openwrt.org"
    if [ ! -e "$profile" ]; then
        echo "Image profile not found. Abort."
        exit 1
    fi
    target=$(grep "^TARGET" "$profile" | cut -d"=" -f2)
    subtarget=$(grep "^SUBTARGET" "$profile" | cut -d"=" -f2)
    devname=$(grep "^PROFILE" "$profile" | cut -d"=" -f2)
    type=$(grep "^TYPE" "$profile" | cut -d"=" -f2)
    packages=$(grep "^PACKAGES" "$profile" | cut -d"=" -f2)
    files=$(grep "^FILES" "$profile" | cut -d"=" -f2)
    dsvcs=$(grep "^DISABLED_SERVICES" "$profile" | cut -d"=" -f2)
    if [ "$type" = "releases" ]; then
        ver=$(grep "^VERSION" "$profile" | cut -d"=" -f2)
        if [ -z "$ver" ]; then
            echo "Missing releases version in the image profile. Abort."
        fi
    fi
    if [ -z "$target" ] || [ -z "$subtarget" ] || [ -z "$devname" ] || [ -z "$type" ] || { [ "$type" != "snapshots" ] && [ "$type" != "releases" ]; }; then
        echo "Invalid image profile. Abort."
        exit 1
    fi

    if [ -e "$confile" ]; then
        local mirror_tmp
        mirror_tmp=$(grep "^MIRROR" "$confile" | cut -d"=" -f2)
        if [ -n "$mirror_tmp" ]; then
            mirror="$mirror_tmp"
        else
            echo "Invalid conf file. Abort."
            exit 1
        fi
    fi
    if [ "$type" = "releases" ]; then
        url=https://"$mirror"/"$type"/"$ver"/targets/"$target"/"$subtarget"
        ib_dir=openwrt-imagebuilder-"$ver"-"$target"-"$subtarget".Linux-x86_64

    else
        url=https://"$mirror"/"$type"/targets/"$target"/"$subtarget"
        ib_dir=openwrt-imagebuilder-"$target"-"$subtarget".Linux-x86_64
    fi
    ib_name="$ib_dir".tar.xz
}

cleanup() {
    rm -rf working/"$ib_dir"* || exit 1
    exit 0
}

build() {
    if [ ! -d working/"$ib_dir" ]; then
        mkdir -p working
        if wget "$url"/"$ib_name" -P working/; then
            tar xf working/"$ib_name" -C working/ || exit 1
            rm working/"$ib_name"
        fi
    fi
    mkdir -p bin
    cd working/"$ib_dir" || exit 1
    if [ ! -d ./bin ]; then
        ln -s ../../bin bin
    fi
    sed -i 's,downloads.openwrt.org,'"$mirror"',g' repositories.conf
    rev=$(grep "^REVISION" include/version.mk | cut -d"=" -f2)
    if [ -z "$rev" ]; then
        echo "Invalid Image Builder."
        exit 1
    else
        make image PROFILE="$devname" PACKAGES="$packages" FILES="$files" DISABLED_SERVICES="$dsvcs" EXTRA_IMAGE_NAME="$rev"
        exit 0
    fi
}
if [ -z "$2" ] || [ -n "$3" ]; then
    usage
fi
init_var "$@"
subcmd="$2"
case $subcmd in
    "clean") cleanup ;;
    "image") build ;;
    *) usage ;;
esac
