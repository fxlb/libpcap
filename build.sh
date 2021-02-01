#!/bin/bash

set -e

travis_fold() {
    local action="${1}"
    local name="${2}"
    echo -e "travis_fold:${action}:$LABEL.script.${name}\\r"
    sleep 1
}

touch .devel configure
for CC in gcc clang; do
    export CC
    if [ $CC = gcc ] && [ "$TRAVIS_OS_NAME" = osx ]; then continue; fi
    for CMAKE in no yes; do
        for REMOTE in disable enable; do
            if [ "$REMOTE" = enable ]; then
                ENABLE_REMOTE="-DENABLE_REMOTE=ON"
            else
                ENABLE_REMOTE=""
            fi
            LABEL="$CC.$CMAKE.$REMOTE"
            echo "===== BUILD: compiler:$CC cmake:$CMAKE remote:$REMOTE ====="
            if [ "$CMAKE" = no ]; then
                echo '$ ./configure [...]'
                travis_fold start configure
                ./configure --prefix=/tmp "--${REMOTE}-remote"
                travis_fold end configure
            else
                mkdir build
                cd build || exit
                echo '$ cmake [...]'
                travis_fold start cmake
                cmake -DCMAKE_INSTALL_PREFIX=/tmp "$ENABLE_REMOTE" ..
                travis_fold end cmake
            fi
            make -s
            make -s testprogs
            echo '$ make install [...]'
            travis_fold start make_install
            PATH=$PATH make install
            travis_fold end make_install
            if [ "$CMAKE" = no ]; then
                testprogs/findalldevstest
            else
                run/findalldevstest
            fi
            if [ "$CMAKE" = no ]; then make releasetar; fi
            echo '$ cat Makefile [...]'
            travis_fold start cat_makefile
            if [ "$CMAKE" = no ]; then
                sed -n '1,/DO NOT DELETE THIS LINE -- mkdep uses it/p' < Makefile
            else
                cat Makefile
            fi
            travis_fold end cat_makefile
            echo '$ cat config.h'
            travis_fold start cat_config_h
            cat config.h
            travis_fold end cat_config_h
            if [ "$CMAKE" = no ]; then
                echo '$ cat config.log'
                travis_fold start cat_config_log
                cat config.log
                travis_fold end cat_config_log
            fi
            if [ "$CMAKE" = yes ]; then cd ..; fi
            echo 'Cleaning...'
            travis_fold start cleaning
            if [ "$CMAKE" = yes ]; then rm -rf build; else make distclean; fi
            travis_fold end cleaning
        done
    done
done
