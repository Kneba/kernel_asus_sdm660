#!/bin/bash

#set -e

KERNELDIR=$(pwd)

# Identity
CODENAME=Hayzel
KERNELNAME=TheOneMemory
VARIANT=HMP
VERSION=EOL

TG_SUPER=1
BOT_BUILD_URL="https://api.telegram.org/bot$TG_TOKEN/sendDocument"

tg_post_build()
{
	if [ $TG_SUPER = 1 ]
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

if ! [ -d "$KERNELDIR/trb_clang" ]; then
echo "trb_clang not found! Cloning..."
if ! git clone https://gitlab.com/varunhardgamer/trb_clang --depth=1 -b 17 --single-branch trb_clang; then
echo "Cloning failed! Aborting..."
exit 1
fi
fi

if ! [ -d "$KERNELDIR/AnyKernel3" ]; then
echo "AnyKernel3 not found! Cloning..."
if ! git clone --depth=1 https://github.com/Tiktodz/AnyKernel3 -b hmp-old AnyKernel3; then
echo "Cloning failed! Aborting..."
exit 1
fi
fi

## Copy this script inside the kernel directory
KERNEL_DEFCONFIG=X00TD_defconfig
ANYKERNEL3_DIR=$KERNELDIR/AnyKernel3/
TZ=Asia/Jakarta
DATE=$(date '+%Y%m%d')
FINAL_KERNEL_ZIP="$KERNELNAME-$VARIANT-$VERSION-$(date '+%Y%m%d-%H%M')"
KERVER=$(make kernelversion)
export PATH="$KERNELDIR/trb_clang/bin:$PATH"
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_USER="queen"
export KBUILD_BUILD_HOST=$(source /etc/os-release && echo "${NAME}")
export KBUILD_COMPILER_STRING="$($KERNELDIR/trb_clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"

# Speed up build process
MAKE="./makeparallel"

BUILD_START=$(date +"%s")
blue='\033[0;34m'
cyan='\033[0;36m'
yellow='\033[0;33m'
red='\033[0;31m'
nocol='\033[0m'

# Java
command -v java > /dev/null 2>&1

# Clean build always lol
# echo "**** Cleaning ****"
# rm -rf TheOneMemory*.zip
mkdir -p out
make O=out clean

echo "**** Kernel defconfig is set to $KERNEL_DEFCONFIG ****"
echo -e "$blue***********************************************"
echo "          BUILDING KERNEL          "
echo -e "$red***********************************************"
make $KERNEL_DEFCONFIG O=out
make -j$(nproc --all) O=out LLVM=1\
		ARCH=arm64 \
		AS="$KERNELDIR/trb_clang/bin/llvm-as" \
		CC="$KERNELDIR/trb_clang/bin/clang" \
		LD="$KERNELDIR/trb_clang/bin/ld.lld" \
		AR="$KERNELDIR/trb_clang/bin/llvm-ar" \
		NM="$KERNELDIR/trb_clang/bin/llvm-nm" \
		STRIP="$KERNELDIR/trb_clang/bin/llvm-strip" \
		OBJCOPY="$KERNELDIR/trb_clang/bin/llvm-objcopy" \
		OBJDUMP="$KERNELDIR/trb_clang/bin/llvm-objdump" \
		CLANG_TRIPLE=aarch64-linux-gnu- \
		CROSS_COMPILE="$KERNELDIR/trb_clang/bin/clang" \
		CROSS_COMPILE_COMPAT="$KERNELDIR/trb_clang/bin/clang" \
		CROSS_COMPILE_ARM32="$KERNELDIR/trb_clang/bin/clang"

echo "$blue**** Kernel Compilation Completed ****"
echo "$cyan**** Verify Image.gz-dtb ****"

if ! [ -f $KERNELDIR/out/arch/arm64/boot/Image.gz-dtb ];then
    echo "$red Compile Failed!!!$nocol"
    exit 1
fi

# Anykernel 3 time!!
echo "$yellow**** Verifying AnyKernel3 Directory ****"
ls $ANYKERNEL3_DIR
# echo "**** Removing leftovers ****"
# rm -rf $ANYKERNEL3_DIR/Image.gz-dtb
# rm -rf $ANYKERNEL3_DIR/$FINAL_KERNEL_ZIP

# Generating Changelog
echo "$red <b><#selectbg_g>$(date)</#></b>"&& echo " " && git log --oneline -n15 | cut -d " " -f 2- | awk '{print "<*> " $(A)}' >> changelog

echo "**** Copying Image.gz-dtb ****"
cp $KERNELDIR/out/arch/arm64/boot/Image.gz-dtb $ANYKERNEL3_DIR/

echo "$cyan**** Time to zip up! ****"
cd $ANYKERNEL3_DIR/
cp -af $KERNELDIR/init.$CODENAME.Spectrum.rc spectrum/init.spectrum.rc && sed -i "s/persist.spectrum.kernel.*/persist.spectrum.kernel TheOneMemory/g" spectrum/init.spectrum.rc
cp -af $KERNELDIR/changelog META-INF/com/google/android/aroma/changelog.txt
cp -af anykernel-real.sh anykernel.sh
sed -i "s/kernel.string=.*/kernel.string=$KERNELNAME/g" anykernel.sh
sed -i "s/kernel.type=.*/kernel.type=$VARIANT/g" anykernel.sh
sed -i "s/kernel.for=.*/kernel.for=$CODENAME/g" anykernel.sh
sed -i "s/kernel.compiler=.*/kernel.compiler=$KBUILD_COMPILER_STRING/g" anykernel.sh
sed -i "s/kernel.made=.*/kernel.made=dotkit @fakedotkit/g" anykernel.sh
sed -i "s/kernel.version=.*/kernel.version=$VERSION/g" anykernel.sh
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

zip -r9 "../$FINAL_KERNEL_ZIP" * -x .git README.md anykernel-real.sh .gitignore zipsigner* "*.zip"

ZIP_FINAL="$FINAL_KERNEL_ZIP"

echo -e "$red**** Done, here is your sha1 ****"

cd ..

sha1sum $FINAL_KERNEL_ZIP

echo -e "$cyan*** Zip signature ***"
curl -sLo zipsigner-3.0.jar https://github.com/Magisk-Modules-Repo/zipsigner/raw/master/bin/zipsigner-3.0-dexed.jar
java -jar zipsigner-3.0.jar "$ZIP_FINAL".zip "$ZIP_FINAL"-signed.zip
ZIP_FINAL="$ZIP_FINAL-signed"

#rm -rf $ANYKERNEL3_DIR/$FINAL_KERNEL_ZIP
#rm -rf $ANYKERNEL3_DIR/Image.gz-dtb
#rm -rf out/*

BUILD_END=$(date +"%s")
DIFF=$(($BUILD_END - $BUILD_START))
echo -e "$cyan Build completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds.$nocol"

echo "$cyan**** Uploading your zip now ****"
tg_post_build "$ZIP_FINAL.zip" "Build completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds"
