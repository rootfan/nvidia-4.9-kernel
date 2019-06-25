#!/bin/bash

export PATH=$P4ROOT/sw/mobile/tools/linux/gradle/gradle-4.1/bin:$PATH
export PATH=$P4ROOT/sw/tools/jdk/linux_x86_64/jdk1.8.0_111/bin:$PATH
export JAVA_HOME=$P4ROOT/sw/tools/jdk/linux_x86_64/jdk1.8.0_111
export ANDROID_HOME=$P4ROOT/sw/tools/android/sdk/r24.4.1-custom
export ANDROID_NDK_HOME=$P4ROOT/sw/tools/android/ndk/r13b

gradle --offline --no-daemon --console=plain clean assemble
