#!/usr/bin/env bash

ONAP_REPOS_DIR=$HOME/onap-source

install_repo_tool() {
  mkdir -p $HOME/bin
  curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
  chmod a+x $HOME/bin/repo
}

initialize_repos_dir() {
  mkdir -p $ONAP_REPOS_DIR
  cd $ONAP_REPOS_DIR
  repo init -u https://github.com/dbainbri-ciena/onap-manifest
}

sync_repos_dir() {
  cd $ONAP_REPOS_DIR
  repo sync --no-clone-bundle
}

if [ ! -f $HOME/bin/repo ]; then
  echo "== Installing Google repo tool =="
  install_repo_tool
fi

if [ ! -d $ONAP_REPOS_DIR/.repo ]; then
  echo -e "== Initializing repos dir $ONAP_REPOS_DIR =="
  initialize_repos_dir
fi

echo -e "== Syncing repos dir $ONAP_REPOS_DIR =="
sync_repos_dir

