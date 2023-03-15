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
    target=$(grep -w "^TARGET" "$profile" | cut -d"=" -f2)
    subtarget=$(grep -w "^SUBTARGET" "$profile" | cut -d"=" -f2)
    devname=$(grep -w "^PROFILE" "$profile" | cut -d"=" -f2)
    type=$(grep -w "^TYPE" "$profile" | cut -d"=" -f2)
    packages=$(grep -w "^PACKAGES" "$profile" | cut -d"=" -f2)
    files=$(grep -w "^FILES" "$profile" | cut -d"=" -f2)
    dsvcs=$(grep -w "^DISABLED_SERVICES" "$profile" | cut -d"=" -f2)
    extpacks="$(pwd)"/packages/"$target"/"$subtarget"
    VERSION_DIST=$(grep -w "^VERSION_DIST" "$profile" | cut -d"=" -f2)
    TARGET_ROOTFS_TARGZ=$(grep -x 'TARGET_ROOTFS_TARGZ=n' "$profile")
    TARGET_ROOTFS_EXT4FS=$(grep -x 'TARGET_ROOTFS_EXT4FS=n' "$profile")
    TARGET_ROOTFS_SQUASHFS=$(grep -x 'TARGET_ROOTFS_SQUASHFS=n' "$profile")
    VDI_IMAGES=$(grep -x 'VDI_IMAGES=y' "$profile")
    VMDK_IMAGES=$(grep -x 'VMDK_IMAGES=y' "$profile")
    VHDX_IMAGES=$(grep -x 'VHDX_IMAGES=y' "$profile")
    declare -ig TARGET_ROOTFS_PARTSIZE=$(grep -w "^TARGET_ROOTFS_PARTSIZE" "$profile" | cut -d"=" -f2)
    if [ -z "$VERSION_DIST" ]; then
        VERSION_DIST="OpenWrt"
    fi
    if [ "$type" = "releases" ]; then
        ver=$(grep -w "^VERSION" "$profile" | cut -d"=" -f2)
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
        mirror_tmp=$(grep -w "^MIRROR" "$confile" | cut -d"=" -f2)
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
    if [ -d "$extpacks" ]; then
        find "$extpacks" -type f -name '*.ipk' -exec ln -s '{}' ./packages/ \; 2>/dev/null
    fi
    sed -i 's,downloads.openwrt.org,'"$mirror"',g' repositories.conf
    rev=$(grep -w "^REVISION" include/version.mk | cut -d"=" -f2)
    if [ -z "$rev" ]; then
        echo "Invalid Image Builder."
        exit 1
    else
        cp .config config.old
        if [ "$target" = "x86" ]; then
            if [ -n "$TARGET_ROOTFS_TARGZ" ]; then
                sed -e '/CONFIG_TARGET_ROOTFS_TARGZ/s/^/#/' -i .config
                echo '# CONFIG_TARGET_ROOTFS_TARGZ is not set' >>.config
            fi
            if [ -n "$TARGET_ROOTFS_EXT4FS" ]; then
                sed -e '/CONFIG_TARGET_ROOTFS_EXT4FS/s/^/#/' -i .config
                echo '# CONFIG_TARGET_ROOTFS_EXT4FS is not set' >>.config
            else
                if [ -n "$VDI_IMAGES" ]; then
                    sed -e 'CONFIG_VDI_IMAGES/s/^/#/' -i .config
                    echo 'CONFIG_VDI_IMAGES=y' >>.config
                fi
                if [ -n "$VMDK_IMAGES" ]; then
                    sed -e 'CONFIG_VMDK_IMAGES/s/^/#/' -i .config
                    echo 'CONFIG_VMDK_IMAGES=y' >>.config
                fi
                if [ -n "$VHDX_IMAGES" ]; then
                    sed -e 'CONFIG_VHDX_IMAGES/s/^/#/' -i .config
                    echo 'CONFIG_VHDX_IMAGES=y' >>.config
                fi
            fi
            if [ -n "$TARGET_ROOTFS_SQUASHFS" ]; then
                sed -e '/CONFIG_TARGET_ROOTFS_SQUASHFS/s/^/#/' -i .config
                echo '# CONFIG_TARGET_ROOTFS_SQUASHFS is not set' >>.config
            fi
            #The official Image builder supports rootfs resize since
            #https://github.com/openwrt/openwrt/commit/7b7edd25a571568438c886529d3443054e02f55f
            if [ "$TARGET_ROOTFS_PARTSIZE" -gt 0 ]; then
                sed -e '/^CONFIG_TARGET_ROOTFS_PARTSIZE/s/^/#/' -i .config
                echo "CONFIG_TARGET_ROOTFS_PARTSIZE=$TARGET_ROOTFS_PARTSIZE" >>.config
            fi
        fi
        if [ "$VERSION_DIST" != "OpenWrt" ]; then
            sed -e '/^CONFIG_VERSION_DIST/s/^/#/' -i .config
            echo CONFIG_VERSION_DIST=\""$VERSION_DIST"\" >>.config
            mkdir -p files/etc/
            cp ../../templates/openwrt_release files/etc/
            if [ -n "$ver" ]; then
                sed -e "s,%V,$ver,g" -i files/etc/openwrt_release
            else
                sed -e "s,%V,SNAPSHOT,g" -i files/etc/openwrt_release
            fi
            sed -e "s,%C,$rev,g" \
                -e "s,%D,$VERSION_DIST,g" \
                -e "s,%R,$rev,g" \
                -e "s,%S,$target/$subtarget,g" \
                -e "s,%A,$(grep ^CONFIG_TARGET_ARCH_PACKAGES .config | cut -d"=" -f2 | sed -e 's/\"//g'),g" \
                -i files/etc/openwrt_release
            files="files"
            make image PROFILE="$devname" PACKAGES="$packages" FILES="$files" DISABLED_SERVICES="$dsvcs" EXTRA_IMAGE_NAME="$rev"
            rm -rf files/etc/openwrt_release
        else
            make image PROFILE="$devname" PACKAGES="$packages" FILES="$files" DISABLED_SERVICES="$dsvcs" EXTRA_IMAGE_NAME="$rev"
        fi
        mv config.old .config
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
