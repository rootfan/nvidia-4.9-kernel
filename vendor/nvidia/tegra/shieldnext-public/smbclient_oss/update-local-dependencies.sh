#!/bin/bash

# Copyright (c) 2014-2015, NVIDIA Corporation.  All rights reserved.
#
# NVIDIA Corporation and its licensors retain all intellectual property and
# proprietary rights in and to this software and related documentation.  Any
# use, reproduction, disclosure or distribution of this software and related
# documentation without an express license agreement from NVIDIA Corporation
# is strictly prohibited.

#
# Script for pulling dependencies into local maven repository for offline
# builds.
#
# This probably could be implemented within the gradle buildscripts without
# need to duplicate the dependencies in dependencies.pom... but this would
# required some gradle-skills.
#

echo
echo
echo "*************************************************************************"
echo
echo "This script pulls project dependencies listed in 'dependencies.pom' to"
echo "local maven repository 'dependencies' for offline builds."
echo
echo "Android studio projects depend on android gradle plugin, which is always"
echo "pulled. IF THE PROJECT HAS ANY OTHER 3RD-PARTY DEPENDENCIES, MAKE SURE"
echo "THAT NVIDIA ALLOWS TO USE THEM."
echo "*************************************************************************"
echo
echo
read -p "Press [enter] to continue or <ctrl>-c to abort"


command -v mvn 2>/dev/null  1>&2 || { echo >&2 "'mvn' not found in path. Please install apache maven"; exit 1; }

rm -rf dependencies

mvn \
    -f dependencies.pom \
    -Dmdep.addParentPoms=true \
    -Dmdep.useRepositoryLayout=true \
    -Dmdep.copyPom=true \
    -DoutputDirectory=`pwd`/dependencies/ \
    org.apache.maven.plugins:maven-dependency-plugin:2.9:copy-dependencies

echo
echo
echo "Dependencies pulled to local maved repository."
echo
echo "Remember to submit any changes in 'dependencies'"
echo "directory into source control."
echo
echo "If this is a new project, create a new build_offline.gradle"
echo "that points to the local repository instead of remote jcenter,"
echo "and use '-b build_offline.gradle' to point gradle to it."
echo
