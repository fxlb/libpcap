#!/bin/bash

set -e

ANSI_MAGENTA="\\033[35;1m"
#ANSI_YELLOW="\\033[33;1m"
ANSI_RESET="\\033[0m"

travis_fold() {
    local action="$1"
    local name="$2"
    echo -e "travis_fold:$action:$LABEL.script.$name\\r"
    sleep 1
}

# Display text in magenta
echo_magenta() {
    echo -ne "$ANSI_MAGENTA"
    echo "$@"
    echo -ne "$ANSI_RESET"
}

touch .devel configure
for CC in gcc clang; do
    export CC
    # Exclude gcc on OSX (it is just an alias for clang)
    if [ "$CC" = gcc ] && [ "$TRAVIS_OS_NAME" = osx ]; then continue; fi
    for CMAKE in no yes; do
        for REMOTE in disable enable; do
            echo_magenta "===== BUILD: compiler:$CC cmake:$CMAKE remote:$REMOTE ====="
            # LABEL is needed to build the travis fold labels
            LABEL="$CC.$CMAKE.$REMOTE"
            if [ "$CMAKE" = yes ]; then
                # ENABLE_REMOTE is only used by cmake
                if [ "$REMOTE" = enable ]; then
                    ENABLE_REMOTE="-DENABLE_REMOTE=ON"
                else
                    ENABLE_REMOTE=""
                fi
            fi
            if [ "$CMAKE" = no ]; then
                echo '$ ./configure [...]'
                travis_fold start configure
                ./configure --prefix=/tmp/local "--$REMOTE-remote"
                travis_fold end configure
            else
                mkdir build
                cd build
                echo '$ cmake [...]'
                travis_fold start cmake
                cmake -DCMAKE_INSTALL_PREFIX=/tmp "$ENABLE_REMOTE" ..
                travis_fold end cmake
            fi
            make -s
            make -s testprogs
            echo '$ make install [...]'
            travis_fold start make_install
            make install
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
            rm -rf /tmp/local
            git status -suall
            git checkout .
            travis_fold end cleaning
        done
    done
done
# vi: set tabstop=4 softtabstop=0 expandtab shiftwidth=4 smarttab autoindent :
