# Morphe Builder

Morphe Builder is a premium, automated build system and pipeline for Android. It compiles and packages customized Android applications as both standard non-root APKs and systemless bind-mount Magisk/KernelSU modules.

---

## Features

* **Parallel Build System:** Compiles multiple applications concurrently using ReVanced CLI.
* **Proactive Module Installer:** The Magisk/KernelSU module installer (`customize.sh`) automatically detects package version mismatches and handles reverting updates or clean uninstalls before installing the required stock APK.
* **Secure Key Management:** Dynamic local keystore generation using OpenSSL, integrated with GitHub Actions Secrets to keep private keys out of the public Git history.

---

## Local Building

### Prerequisites
Make sure your system has the following installed:
* **Java Development Kit (JDK 11 or higher)**
* **jq** (JSON parser)
* **zip** (archive utility)
* **openssl** (for signing certificate queries)

### Running the Build
To execute a build locally, supply your keystore password as an environment variable:
```bash
KEYSTORE_PASSWORD="YOUR_PASSWORD_HERE" ./build.sh
```

---

## GitHub Actions Automated Builds

This project includes a CI/CD workflow located in `.github/workflows/build.yml`. To automate builds on GitHub:

1. **Add Repository Secrets:** Go to your repository settings on GitHub (**Settings > Secrets and variables > Actions**) and add:
   * `KEYSTORE_PASSWORD`: The password of your signing keystore.
   * `KEYSTORE_BASE64`: The base64-encoded string of your `ks.keystore` file.
2. **Trigger Build:** Run the workflow manually from the **Actions** tab.

---

## Credits & Acknowledgments

* **Original Creator:** Special thanks and credit to [j-hc](https://github.com/j-hc) for the original repository templates, scripts, and build system concepts.
