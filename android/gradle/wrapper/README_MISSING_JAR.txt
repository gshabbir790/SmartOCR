gradle-wrapper.jar (binary file) could not be generated in this environment
(no network / no local Gradle install available here).

Fix — pick ONE:
1. Open this project folder in Android Studio once. It detects the missing
   wrapper jar and regenerates it automatically.
2. Or, with Gradle installed locally, run from the android/ folder:
     gradle wrapper --gradle-version 8.10.2
3. Or, with Flutter installed, just run `flutter build apk` from the project
   root once — recent Flutter versions bootstrap the Gradle wrapper jar
   automatically if it's missing.

gradlew and gradlew.bat (the wrapper *scripts*) are already included and
correct — only the jar binary is missing.
