# Display App

> [!IMPORTANT] 
> The Display App was originally created as an early demo during the initial development of EVerest and has evolved over time. It is not intended as a reference implementation for designing display apps for EVerest chargers.
> 
> We currently do not recommend building upon it without a substantial refactoring. The app communicates with EVerest via a deprecated API module, but we recommend using the stable APIs as the old module might be removed any time. Due to limited resources, active development is paused. If you are interested in sponsoring further development, please reach out!

Flutter app for uMWC, BelayBox and uMWCar

The app uses [fvm](https://github.com/leoafarias/fvm) so instead of every flutter command run `fvm flutter <subcommand>` to use the flutter version pinned in the [fvmrc](.fvmrc). The current version should be the same as the one used in the yocto image for the chargers

## Cloud enrollment
The "Cloud" button on the charging dashboard enrolls the charger using a one-time password (OTP) from cloud.pionix.com. It requires the `cloud-connector` CLI at `/usr/bin/cloud-connector` and the `cloud-connector` systemd service on the image; without the CLI, the button is hidden. The app uses these commands (the app runs as root):
- `cloud-connector est status --format json` to check whether the charger is already enrolled
- `cloud-connector est enroll --otp-code <xxxx-xxxx> --format json` to (re-)enroll the charger
- `systemctl restart cloud-connector` to restart the cloud connection of an enrolled charger

The legacy RFC 7030 enrollment (not yet adapted to `cloud-connector`) is hidden by default. To enable it, set the environment variable `DISPLAY_APP_ENABLE_RFC7030=1` (or `true`) for the display app.

## Run locally
If one wants to run the app locally for testing purposes it is important to have a local instance of everest running or the app will be forever stuck on the loading screen.
Follow [the everest setup guide](https://everest.github.io/nightly/general/03_quick_start_guide.html#download-and-install) until step "Software in a loop" (running `./run-sil.sh` is all we need, ./nodered-sil.sh is not required)

### Emulating a different device
Clone [pionix-control](https://github.com/PionixInternal/pionix-control.git) and run `pip install .`. This will install the required tool and one can run `pionix-control --charger-info charger_info/umwcar.yaml --metadata-dir ./env/` in the repos folder to emulate a different device (it might be required to create *env/everest_environment* first: `touch ./env/everest_environment.env` first).

## Run on a remote device
It is possible to run the app remote (eg. on a µmwc) with flutter via ssh, but this requires some setup.
- have a ssh key (usually located at $HOME/.ssh/id_\<keytype>) or generate a new one with `ssh-keygen -t ed25519`
- authenticate to the remote device via your ssh key (if not set up run `ssh-copy-id <remote username, usually root>@<network address of device>`)
- to test if this is working just run `ssh <remote username, usually root>@<network address of device>` and if no password is prompted but the connection is established authentication via the ssh key succeeded
- enable custom devices for flutter: `fvm flutter config --enable-custom-devices`
- proceed to add your device via `fvm flutter custom-devices add`. eg:
  ```console
  fvm flutter custom-devices add
   Please enter the id you want to device to have. Must contain only alphanumeric or underscore characters. (example: pi)
   umwc
   Please enter the label of the device, which is a slightly more verbose name for the device. (example: Raspberry Pi)
   microMegawattCharger
   SDK name and version (example: Raspberry Pi 4 Model B+)
   Raspberry Pi 4 Model B+
   Should the device be enabled? [Y/n] (empty for default)

   Please enter the hostname or IPv4/v6 address of the device. (example: raspberrypi)
   10.10.10.199
   Please enter the username used for ssh-ing into the remote device. (example: pi, empty for no username)
   root
   Please enter the command executed on the remote device for starting the app. "/tmp/${appName}" is the path to the asset bundle. (example: flutter-pi /tmp/${appName})
   flutter-pi /home/root/${appName}
   Should the device use port forwarding? Using port forwarding is the default because it works in all cases, however if your remote device has a static IP address and you have a way of specifying the "--vm-service-host=<ip>"
   engine option, you might prefer not using port forwarding. [Y/n] (empty for default)

   Enter the command executed on the remote device for taking a screenshot. (example: fbgrab /tmp/screenshot.png && cat /tmp/screenshot.png | base64 | tr -d ' \n\t', empty for no screenshotting support)

   Would you like to add the custom device to the config now? [Y/n] (empty for default)
  ```
- this will generate a custom_devices.json for us at *$HOME/.config/flutter*, however we will have to edit it manually as the pregenerated config will not work out-of-the-box for us
  - change
      ```json
      "postBuild": null
      ```
      to
      ```json
      "postBuild": [
      "ssh",
      "<YOUR SSH USER>@<YOUR SSH IP ADDRESS>",
      "bash -c \"mkdir -p /home/root/${appName}/data/flutter_assets && cp /usr/share/flutter/pionixbox/app/lib/icudtl.dat /home/root/${appName}/data/\""
      ],
      ```
  - change
      ```json
      "install": [
        "scp",
        "-r",
        "-o",
        "BatchMode=yes",
        "${localPath}",
        "<YOUR SSH USER>@<YOUR SSH IP ADDRESS>:/tmp/${appName}"
      ],
      ```
      to
      ```json
      "install": [
        "bash",
        "-c",
        "scp -r -o BatchMode=yes ${localPath} <YOUR SSH USER>@<YOUR SSH IP ADDRESS>:/home/root/${appName}/data/"
      ],
      ```
  - change
      ```json
      "uninstall": [
        "ssh",
        "-o",
        "BatchMode=yes",
        "<YOUR SSH USER>@<YOUR SSH IP ADDRESS>",
        "rm -rf \"/tmp/${appName}\""
      ],
      ```
      to
      ```json
      "uninstall": [
        "ssh",
        "-o",
        "BatchMode=yes",
        "<YOUR SSH USER>@<YOUR SSH IP ADDRESS>",
        "rm -rf \"/home/root/${appName}/data/flutter_assets/*\""
      ],
      ```
  - change
      ```json
      "runDebug": [
        "ssh",
        "-o",
        "BatchMode=yes",
        "<YOUR SSH USER>@<YOUR SSH IP ADDRESS>",
        "flutter-pi /home/root/${appName}"
      ],
      ```
      to
      ```json
      "runDebug": [
        "ssh",
        "-o",
        "BatchMode=yes",
        "<YOUR SSH USER>@<YOUR SSH IP ADDRESS>",
        "LD_LIBRARY_PATH=/usr/share/flutter/3.19.2/debug/lib flutter-pi /home/root/${appName}/"
      ],
      ```
- in summary:
  - We use the home directory instead of the default /tmp/-directory to prevent high memory usage
  - we copy an additional file *icudtl.dat* to our app assets as this is required but not included by default
  - we run the app with `LD_LIBRARY_PATH=/usr/share/flutter/3.19.2/debug/lib` as this is also required (if the flutter engine version is updated in the future this has to be adjusted)
- then one can just use this device as a flutter device eg. via `fvm flutter run -d <device name>`
