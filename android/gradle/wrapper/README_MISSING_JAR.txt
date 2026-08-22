gradle-wrapper.jar is intentionally not committed as a binary in this
package (it couldn't be produced in the environment that generated this
project). This is now handled automatically:

gradlew / gradlew.bat check for gradle/wrapper/gradle-wrapper.jar on first
run and download the official one from the Gradle project's own GitHub repo
if it's missing. You need an internet connection the very first time you
run `flutter build apk` (or `./gradlew` directly) — after that it's cached
locally and no further downloads happen.

If that auto-download ever fails (e.g. no internet, or a restrictive
network/proxy blocking raw.githubusercontent.com), just open the project
once in Android Studio instead — it regenerates the wrapper automatically
too.
