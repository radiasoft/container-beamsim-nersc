#!/bin/bash
build_image_base=radiasoft/fedora
build_is_public=1

build_as_root() {
    umask 022
    cd "$build_guest_conf"
    install_yum_install libtool gcc-gfortran fftw2-devel
    local cores=$(grep -c '^core id[[:space:]]*:' /proc/cpuinfo)
    local v=3.2
    curl -L -s -S -O "http://www.mpich.org/static/downloads/$v/mpich-$v.tar.gz"
    tar xzf "mpich-$v.tar.gz"
    cd "mpich-$v"
    ./configure
    make "-j$cores"
    make install
}

build_as_run_user() {
    local cores=$(grep -c '^core id[[:space:]]*:' /proc/cpuinfo)
    MAKE_OPTS=-j$cores bivio_pyenv_2
    pip install numpy
    pip install matplotlib
    MPICC="$(type -p mpicc)" pip install mpi4py
    cd "$build_guest_conf"
    git clone https://github.com/ochubar/SRW
    cd SRW
    # committed *.so files are not so good.
    find . -name \*.so -exec rm {} \;
    perl -pi -e "s/-j\\s*8/-j$cores/" Makefile
    perl -pi -e "s/'fftw'/'sfftw'/" cpp/py/setup.py
    perl -pi -e 's/-lfftw/-lsfftw/; s/\bcc\b/gcc/; s/\bc\+\+/g++/' cpp/gcc/Makefile
    make
    local d=$(python -c 'import sys; from distutils.sysconfig import get_python_lib as g; sys.stdout.write(g())')
    local so=srwlpy.so
    cd env/work/srw_python
    install -m 644 {srwl,uti}*.py "$so" "$d"
    # Make sure permissions after home-env are right
    build_run_user_home_chmod_public
}
