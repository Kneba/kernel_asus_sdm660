#!/bin/bash

KERNELDIR=$(pwd)

# Identity
CODENAME=Hayzel
KERNELNAME=TOM
VARIANT=HMP
VERSION=EOL

# The name of the device for which the kernel is built
MODEL="ZenFone Max Pro M1"

# The codename of the device
DEVICE="X00TD"

# shellcheck source=/etc/os-release
DISTRO=$(source /etc/os-release && echo "${NAME}")
KBUILD_BUILD_HOST=$(uname -a | awk '{print $2}')
CI_BRANCH=$(git rev-parse --abbrev-ref HEAD)
TERM=xterm
export KBUILD_BUILD_HOST CI_BRANCH TERM

# Specify linker.
# 'ld.lld'(default)
LINKER=ld.lld

CHANGELOGS=https://github.com/strongreasons/android_kernel_asus_sdm660/commits/wip/

TG_TOPIC=0
BOT_MSG_URL="https://api.telegram.org/bot$TG_TOKEN/sendMessage"
BOT_BUILD_URL="https://api.telegram.org/bot$TG_TOKEN/sendDocument"
PROCS=$(nproc --all)

tg_post_build()
{
	if [ $TG_TOPIC = 1 ]
	then
	    curl -F document=@"$1" "$BOT_BUILD_URL" \
	    -F chat_id="$TG_CHAT_ID"  \
	    -F "disable_web_page_preview=true" \
	    -F "parse_mode=Markdown" \
	    -F caption="$2"
	else
	    curl -F document=@"$1" "$BOT_BUILD_URL" \
	    -F chat_id="$TG_CHAT_ID"  \
	    -F "disable_web_page_preview=true" \
	    -F "parse_mode=Markdown" \
	    -F caption="$2"
	fi
}

tg_post_msg(){
        if [ $TG_SUPER = 1 ]
        then
            curl -s -X POST "$BOT_MSG_URL" \
            -d chat_id="$TG_CHAT_ID" \
            -d message_thread_id="$TG_TOPIC_ID" \
            -d "disable_web_page_preview=true" \
            -d "parse_mode=html" \
            -d text="$1"
        else
            curl -s -X POST "$BOT_MSG_URL" \
            -d chat_id="$TG_CHAT_ID" \
            -d "disable_web_page_preview=true" \
            -d "parse_mode=html" \
            -d text="$1"
        fi
}

## Cloning toolchain
if ! [ -d "$KERNELDIR/ew" ]; then
mkdir -p $KERNELDIR/ew && cd $KERNELDIR/ew
wget -q https://github.com/Tiktodz/electrowizard-clang/releases/download/ElectroWizard-Clang-18.1.8-release/ElectroWizard-Clang-18.1.8.tar.gz -O "ElectroWizard-Clang-18.1.8.tar.gz"
tar -xf ElectroWizard-Clang-18.1.8.tar.gz
rm -rf ElectroWizard-Clang-18.1.8.tar.gz
cd ..
fi

## Copy this script inside the kernel directory
KERNEL_DEFCONFIG=X00TD_defconfig
ANYKERNEL3_DIR=$KERNELDIR/AnyKernel3/
TZ=Asia/Jakarta
DATE=$(date '+%Y%m%d')
DATE2=$(date '+%Y%m%d-%H%M')
BUILD_START=$(date +"%s")
FINAL_KERNEL_ZIP="$KERNELNAME-$VARIANT-$VERSION-$DATE"
KERVER=$(make kernelversion)
# Set a commit head
COMMIT_HEAD=$(git log --oneline -1)

# Exporting
export PATH="$KERNELDIR/ew/bin:$PATH"
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_USER="queen"
export LD=ld.lld
export LLVM=1
export LLVM_IAS=1
export KBUILD_COMPILER_STRING="$($KERNELDIR/ew/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"
ClangMoreStrings="AR=llvm-ar NM=llvm-nm AS=llvm-as STRIP=llvm-strip OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump READELF=llvm-readelf HOSTAR=llvm-ar HOSTAS=llvm-as LD_LIBRARY_PATH=$KERNELDIR/ew/lib LD=ld.lld HOSTLD=ld.lld"

# Speed up build process
MAKE="./makeparallel"

# Java
command -v java > /dev/null 2>&1

# Cleaning out
mkdir -p out
make O=out clean

tg_post_msg "<b>😡 Build Triggered</b>%0A<b>Docker OS: </b><code>$DISTRO</code>%0A<b>Kernel Version : </b><code>$KERVER</code>%0A<b>Date : </b><code>$(TZ=Asia/Jakarta date)</code>%0A<b>Device : </b><code>$MODEL [$DEVICE]</code>%0A<b>Pipeline Host : </b><code>$KBUILD_BUILD_HOST</code>%0A<b>Host Core Count : </b><code>$PROCS</code>%0A<b>Compiler Used : </b><code>$KBUILD_COMPILER_STRING</code>%0A<b>Linker : </b><code>$LINKER</code>%0a<b>Branch : </b><code>$CI_BRANCH</code>%0A<b>Top Commit : </b><code>$COMMIT_HEAD</code>%0A<a href='$CHANGELOGS'>Changes from previous release</a>"

# Starting compilation
make $KERNEL_DEFCONFIG O=out 2>&1 | tee -a error.log
make -j$(nproc --all) O=out \
		ARCH=$ARCH \
		SUBARCH=$ARCH \
		CC="$KERNELDIR/ew/bin/clang" \
		CROSS_COMPILE=aarch64-linux-gnu- \
		HOSTCC="$KERNELDIR/ew/bin/clang" \
		HOSTCXX="$KERNELDIR/ew/bin/clang++" ${ClangMoreStrings} 2>&1 | tee -a error.log

if ! [ -f $KERNELDIR/out/arch/arm64/boot/Image.gz-dtb ];then
    tg_post_build "error.log" "Build Error!"
    exit 1
fi

# Anykernel3 time!!
if ! [ -d "$KERNELDIR/AnyKernel3" ]; then
git clone --depth=1 https://github.com/Tiktodz/AnyKernel3 -b hmp-old AnyKernel3
ls $ANYKERNEL3_DIR
cp $KERNELDIR/out/arch/arm64/boot/Image.gz-dtb $ANYKERNEL3_DIR
fi

# Zipping time!!
cd $ANYKERNEL3_DIR/
cp -af $KERNELDIR/init.$CODENAME.Spectrum.rc spectrum/init.spectrum.rc && sed -i "s/persist.spectrum.kernel.*/persist.spectrum.kernel TheOneMemory/g" spectrum/init.spectrum.rc
cp -af $KERNELDIR/changelog META-INF/com/google/android/aroma/changelog.txt
cp -af anykernel-real.sh anykernel.sh
sed -i "s/kernel.string=.*/kernel.string=$KERNELNAME/g" anykernel.sh
sed -i "s/kernel.type=.*/kernel.type=$VARIANT/g" anykernel.sh
sed -i "s/kernel.for=.*/kernel.for=$CODENAME/g" anykernel.sh
sed -i "s/kernel.compiler=.*/kernel.compiler=$KBUILD_COMPILER_STRING/g" anykernel.sh
sed -i "s/kernel.made=.*/kernel.made=dotkit @fakedotkit/g" anykernel.sh
sed -i "s/kernel.version=.*/kernel.version=$KERVER/g" anykernel.sh
sed -i "s/message.word=.*/message.word=Appreciate your efforts for choosing TheOneMemory kernel./g" anykernel.sh
sed -i "s/build.date=.*/build.date=$DATE/g" anykernel.sh
sed -i "s/build.type=.*/build.type=$VERSION/g" anykernel.sh
sed -i "s/supported.versions=.*/supported.versions=9-13/g" anykernel.sh
sed -i "s/device.name1=.*/device.name1=X00TD/g" anykernel.sh
sed -i "s/device.name2=.*/device.name2=X00T/g" anykernel.sh
sed -i "s/device.name3=.*/device.name3=Zenfone Max Pro M1 (X00TD)/g" anykernel.sh
sed -i "s/device.name4=.*/device.name4=ASUS_X00TD/g" anykernel.sh
sed -i "s/device.name5=.*/device.name5=ASUS_X00T/g" anykernel.sh
sed -i "s/X00TD=.*/X00TD=1/g" anykernel.sh
cd META-INF/com/google/android
sed -i "s/KNAME/$KERNELNAME/g" aroma-config
sed -i "s/KVER/$KERVER/g" aroma-config
sed -i "s/KAUTHOR/dotkit @fakedotkit/g" aroma-config
sed -i "s/KDEVICE/Zenfone Max Pro M1/g" aroma-config
sed -i "s/KBDATE/$DATE/g" aroma-config
sed -i "s/KVARIANT/$VARIANT/g" aroma-config
cd ../../../..

zip -r9 "../$FINAL_KERNEL_ZIP" * -x .git README.md anykernel-real.sh ./*placeholder .gitignore zipsigner* "*.zip"

ZIP_FINAL="$FINAL_KERNEL_ZIP"

cd ..

curl -sLo zipsigner-3.0.jar https://github.com/Magisk-Modules-Repo/zipsigner/raw/master/bin/zipsigner-3.0-dexed.jar
java -jar zipsigner-3.0.jar "$ZIP_FINAL".zip "$ZIP_FINAL"-signed.zip
ZIP_FINAL="$ZIP_FINAL-signed"

BUILD_END=$(date +"%s")
DIFF=$(($BUILD_END - $BUILD_START))

tg_post_build "$ZIP_FINAL.zip" "Build completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s)"
