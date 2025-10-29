#!/usr/bin/env bash

# This is an interactive script, just run it without argument and you'll be guided

set -e

dockerfile_args_path="./Dockerfile-args.downstream"
branch_suffix=""

if ls ./.tekton/netobserv-ebpf-agent* 1> /dev/null 2>&1; then
  cpnt="netobserv-ebpf-agent"
  echo "Detected to run for the netobserv eBPF agent repository."
elif ls ./.tekton/flowlogs-pipeline* 1> /dev/null 2>&1; then
  cpnt="flowlogs-pipeline"
  dockerfile_args_path="./contrib/docker/Dockerfile-args.downstream"
  echo "Detected to run for the flowlogs-pipeline repository."
elif ls ./.tekton/network-observability-console-plugin-pf4* 1> /dev/null 2>&1; then
  cpnt="network-observability-console-plugin-pf4"
  branch_suffix="-pf4"
  echo "Detected to run for the netobserv Console plugin repository, PF4 variant."
elif ls ./.tekton/network-observability-console-plugin* 1> /dev/null 2>&1; then
  cpnt="network-observability-console-plugin"
  echo "Detected to run for the netobserv Console plugin repository, no variant."
elif ls ./.tekton/network-observability-cli* 1> /dev/null 2>&1; then
  cpnt="network-observability-cli"
  echo "Detected to run for the netobserv CLI repository."
elif ls ./.tekton/network-observability-operator* 1> /dev/null 2>&1; then
  cpnt="network-observability-operator"
  cpnt2="network-observability-operator-bundle"
  echo "Detected to run for the netobserv operator/bundle repository."
else
  echo "Tekton files not found. Make sure to run this script from the target repository."
  exit 1
fi
read -p "Is it correct? [y/N] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
  exit 0
fi

current=`cat ${dockerfile_args_path} | grep "BUILDVERSION=" | sed -r 's/BUILDVERSION=(.+)/\1/'`
x=`echo ${current} | cut -d . -f1`
y=`echo ${current} | cut -d . -f2`
z=`echo ${current} | cut -d . -f3`
release_branch="release-${x}.${y}${branch_suffix}"
main_branch="main${branch_suffix}"

initial_branch=`git rev-parse --abbrev-ref HEAD`
restore_branch() {
  branch=`git rev-parse --abbrev-ref HEAD`
  if [[ $branch != $initial_branch ]]; then
    echo "Restoring checked-out branch"
    git checkout $initial_branch
  fi
}
trap restore_branch EXIT

echo "This script should run from the branch that was just released: it uses the current version, as defined in Dockerfile-args.downstream, to know which branches to update."
echo "Current version detected: $current ($x.$y.$z)"
if [[ "${z}" == "0" ]]; then
  next_y="$x.$((y+1)).$z"
  next_z="$x.$y.$((z+1))"
  next_branches="'next-${main_branch}' and 'next-${release_branch}'"
  echo "Next versions to prepare:"
  echo "- ${next_y} for branch '${main_branch}'"
  echo "- ${next_z} for branch '${release_branch}'"
  echo "Changes will be done to the local branches ${next_branches}, so make sure it's fine to overwrite before you continue"
else
  next_z="$x.$y.$((z+1))"
  next_branches="'next-${release_branch}'"
  echo "Next version to prepare:"
  echo "- ${next_z} for branch '${release_branch}'"
  echo "Changes will be done to the local branch ${next_branches}, so make sure it's fine to overwrite before you continue"
fi
read -p "Are we good? [y/N] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
  exit 0
fi

git fetch upstream

echo ""
echo "Preparing next-${release_branch} for ${next_z}"
git branch -D next-${release_branch} || true
git checkout -b next-${release_branch} upstream/${release_branch}

echo "Updating Dockerfile-args.downstream..."
sed -i -r "s/^BUILDVERSION=.+/BUILDVERSION=${next_z}/" ${dockerfile_args_path}

check_tekton_z() {
  local tekt_y=$1
  local tekt_z=$2

  if [[ -f $tekt_y ]]; then
    if [[ ! -f $tekt_z ]]; then
      echo "  Converting $tekt_y to zstream..."
      mv $tekt_y $tekt_z
      sed -i -r "s/ystream/zstream/g" $tekt_z
    else
      echo "  WARNING: both ystream and zstream files found ($tekt_y, $tekt_z); please double-check the configuration, should be only one."
    fi
  elif [[ -f $tekt_z ]]; then
    echo "  No ystream conversion needed"
  else
    echo "  ERROR: missing tekton files ($tekt_y or $tekt_z)"
    exit -1
  fi
  echo "  Setting branch '${release_branch}' in $tekt_z..."
  sed -i -r "s/\"(main(${branch_suffix})?|release-[0-9]+\.[0-9]+(${branch_suffix})?)\"/\"${release_branch}\"/g" $tekt_z
}

echo "Checking for .tekton files..."
check_tekton_z "./.tekton/${cpnt}-ystream-pull-request.yaml" "./.tekton/${cpnt}-zstream-pull-request.yaml"
check_tekton_z "./.tekton/${cpnt}-ystream-push.yaml" "./.tekton/${cpnt}-zstream-push.yaml"
if [[ "$cpnt2" != "" ]]; then
  check_tekton_z "./.tekton/${cpnt2}-ystream-pull-request.yaml" "./.tekton/${cpnt2}-zstream-pull-request.yaml"
  check_tekton_z "./.tekton/${cpnt2}-ystream-push.yaml" "./.tekton/${cpnt2}-zstream-push.yaml"
fi

git add -A

echo ""
echo "$next_z done!"
echo "Before we commit, double-check the changes. In summary, we expect:"
echo "- The Dockerfile-args.downstream file to point to the next version ($next_z)"
echo "- The tekton pipelines (on-push and on-pull-request) to have their on-cel-expression hook targetting the desired branch ($release_branch)"
echo "- The tekton pipelines (on-push and on-pull-request) to point to zstream in Konflux/quay/etc."
echo ""
echo "You can also bring manual changes before coming back here and continue."
echo ""
read -p "Press any key to continue (diff will be displayed) " -n 1 -r
git diff HEAD

read -p "Looks good to you? [y/N] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
  exit 0
fi

git commit --allow-empty -m "Prepare $next_z"

check_tekton_y() {
  local tekt_y=$1
  local tekt_z=$2
  if [[ -f $tekt_y ]]; then
    echo "  There should be no change to bring in $tekt_y"
  else
    echo "  ERROR: missing tekton file $tekt_y"
    exit -1
  fi
  if [[ -f $tekt_z ]]; then
    echo "  WARNING: unexpected zstream file found ($tekt_z); branching issue? Please double-check the configuration, it shouldn't be there."
  fi
}

if [[ "${z}" == "0" ]]; then
  echo "Preparing next-${main_branch} for ${next_y}"
  git branch -D next-${main_branch} || true
  git checkout -b next-${main_branch} upstream/${main_branch}

  echo "Updating Dockerfile-args.downstream..."
  sed -i -r "s/^BUILDVERSION=.+/BUILDVERSION=${next_y}/" ${dockerfile_args_path}
  sed -i -r "s/^BUILDVERSION_Y=.+/BUILDVERSION_Y=$x.$((y+1))/" ${dockerfile_args_path}

  echo "Checking for .tekton files..."
  check_tekton_y "./.tekton/${cpnt}-ystream-pull-request.yaml" "./.tekton/${cpnt}-zstream-pull-request.yaml"
  check_tekton_y "./.tekton/${cpnt}-ystream-push.yaml" "./.tekton/${cpnt}-zstream-push.yaml"
  if [[ "$cpnt2" != "" ]]; then
    check_tekton_y "./.tekton/${cpnt2}-ystream-pull-request.yaml" "./.tekton/${cpnt2}-zstream-pull-request.yaml"
    check_tekton_y "./.tekton/${cpnt2}-ystream-push.yaml" "./.tekton/${cpnt2}-zstream-push.yaml"
  fi
  git add -A

  echo ""
  echo "$next_y done!"
  echo "Before we commit, double-check the changes. In summary, we expect:"
  echo "- The Dockerfile-args.downstream file to point to the next version ($next_y)"
  echo "- The tekton pipelines (on-push and on-pull-request) to have their on-cel-expression hook targetting the desired branch (${main_branch})"
  echo "- The tekton pipelines (on-push and on-pull-request) to point to ystream in Konflux/quay/etc."
  echo ""
  echo "You can also bring manual changes before coming back here and continue."
  echo ""
  read -p "Press any key to continue (diff will be displayed) " -n 1 -r
  git diff HEAD

  read -p "Looks good to you? [y/N] " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]
  then
    exit 0
  fi

  git commit --allow-empty -m "Prepare $next_y"
fi

echo ""
echo "🤞 You should be all good to push ${next_branches} to upstream 🤞"
