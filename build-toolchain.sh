#!/bin/bash

#
# Copyright 2015, Alexander von Gluck IV <kallisti5@unixzen.com>
# Script released under the terms of the MIT license
#

#GCCVER="5.2.0"
GCCVER="4.9.3"
BINUTILSVER="2.25.1"

NEWLIBVER=2.2.0.20150623

TARGETMACH=sh-elf
PROGPREFIX=sh2-elf-

OBJFORMAT=ELF

WORKROOT=${PWD}/work
DOWNLOADDIR=${WORKROOT}/download
BUILDDIR=${WORKROOT}/build
SOURCEDIR=${WORKROOT}/source
INSTALLDIR=${WORKROOT}/toolchain
SYSROOTDIR=${WORKROOT}/sysroot

# Clean up
[ -d $INSTALLDIR ] && rm -rf $INSTALLDIR
[ -d $SOURCEDIR ] && rm -rf $SOURCEDIR
[ -d $BUILDDIR ] && rm -rf $BUILDDIR
[ -d $SYSROOTDIR ] && rm -rf $SYSROOTDIR

# Made directories
mkdir -p ${WORKROOT}
mkdir -p ${BUILDDIR}
mkdir -p ${DOWNLOADDIR}
mkdir -p ${SOURCEDIR}
mkdir -p ${INSTALLDIR}
mkdir -p ${SYSROOTDIR}

if [ -z $NPROC ]; then
	export NCPU=`nproc`
fi

# Use tools once we build'em
export PATH=${INSTALLDIR}/bin:$PATH

BINUTILS_CFLAGS="-s"
GCC_BOOTSTRAP_FLAGS="--with-cpu=m2"
GCC_FINAL_FLAGS="--with-cpu=m2 --with-sysroot=${SYSROOTDIR}"

function download() {
	cd ${DOWNLOADDIR}
	wget -c ftp://ftp.gnu.org/gnu/gnu-keyring.gpg

	if [ ! -f ${DOWNLOADDIR}/binutils-${BINUTILSVER}.tar.bz2 ]; then
		wget -c ftp://ftp.gnu.org/gnu/binutils/binutils-${BINUTILSVER}.tar.bz2.sig
		wget -c ftp://ftp.gnu.org/gnu/binutils/binutils-${BINUTILSVER}.tar.bz2
	fi
	if [ ! -f ${DOWNLOADDIR}/gcc-${GCCVER}.tar.bz2 ]; then
		wget -c ftp://ftp.gnu.org/gnu/gcc/gcc-${GCCVER}/gcc-${GCCVER}.tar.bz2
		wget -c ftp://ftp.gnu.org/gnu/gcc/gcc-${GCCVER}/gcc-${GCCVER}.tar.bz2.sig
	fi
	if [ ! -f ${DOWNLOADDIR}/newlib-${NEWLIBVER}.tar.gz ]; then
		wget -c ftp://sourceware.org/pub/newlib/newlib-${NEWLIBVER}.tar.gz
	fi
}

function verify() {
	KEYRING=${DOWNLOADDIR}/gnu-keyring.gpg

	gpg --verify --keyring ${KEYRING} ${DOWNLOADDIR}/binutils-${BINUTILSVER}.tar.bz2.sig
	if [ $? -ne 0 ]; then
		if [ $? -ne 0 ]; then
			echo "Failed to verify GPG signature for binutils"
			exit 1
		fi
	fi
	
	gpg --verify --keyring ${KEYRING} ${DOWNLOADDIR}/gcc-${GCCVER}.tar.bz2.sig
	if [ $? -ne 0 ]; then
		if [ $? -ne 0 ]; then
			echo "Failed to verify GPG signautre for gcc"
			exit 1
		fi
	fi
}

function extract() {
	cd ${SOURCEDIR}
	if [ ! -d binutils-${BINUTILSVER} ]; then
		tar xjpf ${DOWNLOADDIR}/binutils-${BINUTILSVER}.tar.bz2
		[ $? -gt 0 ] && exit 1
	fi

	if [ ! -d gcc-${GCCVER} ]; then
		tar xjpf ${DOWNLOADDIR}/gcc-${GCCVER}.tar.bz2
		[ $? -gt 0 ] && exit 1
	fi
	
	if [ ! -d newlib-${NEWLIBVER} ]; then
		tar xzpf ${DOWNLOADDIR}/newlib-${NEWLIBVER}.tar.gz
		[ $? -gt 0 ] && exit 1
	fi

	# Get all the needed things
	cd $SOURCEDIR/gcc-${GCCVER}
	./contrib/download_prerequisites
	[ $? -gt 0 ] && exit 1
}

cd ${BUILDROOT}
echo "= Downloading... =============="
download;
echo "= Verifying... ================"
verify;
echo "= Extracting... ==============="
extract;


######################################################
# COMPILE BINUTILS
######################################################
echo "= Compiling binutils... ======="
[ -d $BUILDDIR/binutils ] && rm -rf $BUILDDIR/binutils

mkdir -p $BUILDDIR/binutils
cd $BUILDDIR/binutils

export CFLAGS=${BINUTILS_CFLAGS}
export CXXFLAGS="-s"

$SOURCEDIR/binutils-${BINUTILSVER}/configure \
	--disable-werror --target=${TARGETMACH} --prefix=${INSTALLDIR} \
	--with-sysroot=$SYSROOTDIR --program-prefix=${PROGPREFIX} \
	--disable-nls --enable-languages=c
[ $? -gt 0 ] && exit 1

make -j${NCPU}
[ $? -gt 0 ] && exit 1
make install -j${NCPU}
[ $? -gt 0 ] && exit 1

######################################################
# COMPILE GCC-BOOTSTRAP
######################################################
echo "= Compiling gcc-bootstrap... ======="

[ -d $BUILDDIR/gcc-bootstrap ] && rm -rf $BUILDDIR/gcc-bootstrap

mkdir -p $BUILDDIR/gcc-bootstrap
cd $BUILDDIR/gcc-bootstrap
export CFLAGS="-s"
export CXXFLAGS="-s"

$SOURCEDIR/gcc-${GCCVER}/configure \
	--target=${TARGETMACH} \
	--prefix=${INSTALLDIR} --without-headers --enable-bootstrap \
	--enable-languages=c,c++ --disable-threads --disable-libmudflap \
	--with-gnu-ld --with-gnu-as --with-gcc --disable-libssp --disable-libgomp \
	--disable-nls --disable-shared --program-prefix=${PROGPREFIX} \
	--with-newlib --disable-multilib --disable-libgcj \
	--without-included-gettext --disable-libstdcxx \
	${GCC_BOOTSTRAP_FLAGS}
[ $? -gt 0 ] && exit 1

make all-gcc -j${NCPU}
[ $? -gt 0 ] && exit 1
make install-gcc -j${NCPU}
[ $? -gt 0 ] && exit 1

make all-target-libgcc -j${NCPU}
[ $? -gt 0 ] && exit 1
make install-target-libgcc -j${NCPU}
[ $? -gt 0 ] && exit 1

######################################################
# COMPILE NEWLIB
######################################################
echo "= Compiling newlib... ======="
[ -d $BUILDDIR/newlib ] && rm -rf $BUILDDIR/newlib

mkdir -p $BUILDDIR/newlib
cd $BUILDDIR/newlib

export CROSS=${PROGPREFIX}
export CC_FOR_TARGET=${PROGPREFIX}gcc
export LD_FOR_TARGET=${PROGPREFIX}ld
export AS_FOR_TARGET=${PROGPREFIX}as
export AR_FOR_TARGET=${PROGPREFIX}ar
export RANLIB_FOR_TARGET=${PROGPREFIX}ranlib

export newlib_cflags="${newlib_cflags} -DPREFER_SIZE_OVER_SPEED -D__OPTIMIZE_SIZE__"

$SOURCEDIR/newlib-${NEWLIBVER}/configure --prefix=${INSTALLDIR} \
	--target=$TARGETMACH --enable-newlib-nano-malloc \
	--enable-target-optspace
[ $? -gt 0 ] && exit 1

make all -j${NCPU}
[ $? -gt 0 ] && exit 1
make install -j${NCPU}
[ $? -gt 0 ] && exit 1

######################################################
# COMPILE GCC FINAL
######################################################
echo "= Compiling gcc-final... ======="
[ -d $BUILDDIR/gcc-final ] && rm -rf $BUILDDIR/gcc-final

mkdir $BUILDDIR/gcc-final
cd $BUILDDIR/gcc-final

export CFLAGS="-s"
export CXXFLAGS="-s"

$SOURCEDIR/gcc-${GCCVER}/configure \
	--target=${TARGETMACH} --prefix=${INSTALLDIR} \
	--enable-languages=c,c++ --with-gnu-as --with-gnu-ld \
	--disable-shared --disable-threads --disable-multilib \
	--disable-libmudflap --disable-libssp --enable-lto \
	--disable-nls --with-newlib \
	--program-prefix=${PROGPREFIX} ${GCC_FINAL_FLAGS}
[ $? -gt 0 ] && exit 1

make -j${NCPU}
[ $? -gt 0 ] && exit 1

make install -j${NCPU}
[ $? -gt 0 ] && exit 1

echo "== Build of SuprH toolchain is complete! ========"
