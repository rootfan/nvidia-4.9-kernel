Build Instructions:
1. Create a local.properties file in this directory.
2. In local.properties, insert these two lines:
    sdk.dir = [path to your sdk directory]
    ndk.dir = [path to your ndk directory]
Min SDK = 24.4.1
Min NDK = r13b 
Min JDK = jdk1.8.0_111
Min Gradle = gradle-4.1 
3. Also export these paths:
export PATH=[path to jdk]/jdk1.8.0_111/bin:$PATH
export JAVA_HOME=[path to jdk]/jdk1.8.0_111
3. Run ./gradlew build to build debug apk
   Run ./gradlew clean to clean project
