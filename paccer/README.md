# Paccer Utility

This utility is used to patch ReVanced integration checks in `shared.dex` files. It targets classes ending with `/Check;` and methods named `shouldRun()`, rewriting them to return `false`.

## Building the Jar File

If you have a Java JDK (v11 or higher) installed, you can compile and rebuild `paccer.jar` using these commands from the `paccer/` directory:

1. **Create compile output directory:**
   ```bash
   mkdir -p out
   ```

2. **Compile the Java source file:**
   ```bash
   javac -cp ../bin/dexlib2.jar src/com/bizarre/Main.java -d out
   ```

3. **Pack into a JAR file and replace the existing one:**
   ```bash
   jar -cvf ../bin/paccer.jar -C out .
   ```

4. **Clean up compilation artifacts:**
   ```bash
   rm -rf out
   ```
