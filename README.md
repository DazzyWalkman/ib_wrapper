This is a wrapper script for the OpenWrt image builder. It will download the respective image builder and build the firmware image according to the user-specified image profile.

**Prerequisites**: Same as the OpenWrt image builder.

**Usage**:

execute the script in its directory:

`./build.sh <path and filename of the image profile> <action>`

action type:

**image**: build the firmware image according to the user-specified image profile.

**clean**: remove the respective image builder files in the working directory acoording to the user-specified image profile.

**Examples**:

**build a firmware for profile 'profile_example'**: `./build.sh profile/profile_example image`

The resulting image file will be placed in the bin directory.

**remove a device-related image builder files**: `./build.sh profile/profile_example clean`

This will remove the image builder files for the subtarget defined in the profile 'profile_example' in the working directory.

**Configuration**:

Please refer to conf/main.conf.example

**Image profile**:

Please refer to profile/profile_example

**Custom packages**:
If there is a custom package or ipk the user would prefer to use, the user can execute 
`mkdir -p packages/<target>/<subtarget>`
in the ib_wrapper directory, 
then place the custom ipk within the `<subtarget>` directory.
For example, if there is a custom package a.ipk for x86_64, place the a.ipk into the packages/x86/64 directory, then the x86_64 image builder can install the a.ipk to the resulting build, when the image profile calls for the said package.  

**See also**:
https://openwrt.org/docs/guide-user/additional-software/imagebuilder
