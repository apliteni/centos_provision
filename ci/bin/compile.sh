#!/usr/bin/env bash

ROOT_DIR="."
SCRIPTS_DIR="$ROOT_DIR/scripts"
RELEASE_VERSION="$(cat $ROOT_DIR/RELEASE_VERSION)"
echo "Set current release to $RELEASE_VERSION"
sed -i "s/^RELEASE_VERSION=.*/RELEASE_VERSION='$RELEASE_VERSION'/g" $SCRIPTS_DIR/src/shared/vars/common.sh
cd $SCRIPTS_DIR

compile_template(){
  cp $1 $2
  bin/postprocess_requires $2
  chmod a+x $2
}

compile_template src/installer.sh.tpl install.sh
compile_template src/ssl_enabler.sh.tpl enable-ssl.sh
compile_template src/site_adder.sh.tpl add-site.sh
compile_template src/run_command_tester.sh.tpl test-run-command.sh
echo -e "\e[32mCompile $RELEASE_VERSION version complete"