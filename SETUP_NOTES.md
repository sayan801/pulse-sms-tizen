# Tizen Build/Distribution Notes

These are my notes on the build system and creating a signed build of the app, for the Samsung store. I have all of this set up on Jenkins to run automatically, but just in case I ever need to re-configure it...

I do everything I can of this through the CLI SDK. The IDE is terrible. The only thing I wasn't able to do through the CLI was create the distribution certificates.

## Building the App

#### Generate an author and distribution certificate

Obviously I will need to continue to use the cert that I originally uploaded the app with, to sign for the store distribution. This is how I created it.

```
$ tizen certificate -a PulseSMS \
    -p <cert-password> \
    -c US \
    -s Iowa \
    -ct Ankeny \
    -o "Klinker Apps" \
    -n "Luke Klinker" \
    -e luke@klinkerapps.com \
    -f pulse-tizen-cert
```

This generated an "author" certificate in the `$TIZEN_SDK/tizen-studio-data/keystore/author/pulse-tizen-cert.p12`.

You also need to create a "distribution" certificate, if you want to upload to the store, or even install on a device through `sdb`. I couldn't find a way to do this through the CLI. I used the steps, [here](https://developer.samsung.com/galaxy-watch/develop/getting-certificates/create).

#### Applying the certificates to a security profile

After generating the signing credentials, we apply it to a security profile. The profile just holds the information on the certificates and the passwords. It is local to each machine and can be regenerated, as long as the underlying author and distribution certs are the same. It simply centralizes the certifcate information. See the [reference](https://developer.tizen.org/development/tizen-studio/web-tools/cli#Issue_tizen_cert) to learn more about the required parameters.

```
$ tizen security-profiles add -n PulseProfile \
    -a /home/klinkerapps/SamsungCertificate/PulseSMS/author.p12 -p <cert-password> \
    -d /home/klinkerapps/SamsungCertificate/PulseSMS/distributor.p12 -dp <cert-password>
```

#### Building a packaged version of the app, with the security profile

```
# build the Vue project and apply it to the Tizen app
$ cd web
$ npm install
$ npm run tizen

# build the Tizen web app
$ cd ../tizen
$ tizen cli-config "profiles.path=$TIZEN_SDK/tizen-studio-data/profile/profiles.xml"
$ tizen package -t wgt -s PulseProfile
```

## Setting up the Emulator

Again, using the CLI:

```
# download and install the emulator and wearable image
$ cd $TIZEN_STUDIO/package-manager
$ ./package-manager-cli.bin install Emulator
$ ./package-manager-cli.bin install WEARABLE-4.0-Emulator

# figure out the name of the emulator image you just installed
$ cd $TIZEN_STUDIO/tools/emulator/bin
$ ./em-cli list-package

# create and launch the emulator image
$ ./em-cli create -n test-vm -p wearable-4.0-circle-x86
$ ./em-cli launch -n test-vm
```

## Debugging to a Physical Device

We will use Samsung's `$<TIZEN_STUDIO>/tools/sdb` command (similar to `adb`). Again, it is included in the CLI SDK.

First, turn on the developer options and allow debugging:

1. Go to About Watch -> Software -> Tap the "Software Version" until the developer options are enabled
2. Go to About Watch -> Enable debugging
3. Restart the watch

Next, get the IP address of the watch so that we can connect to it:

1. Connect the watch to WiFi. You will have to turn off the bluetooth connection.
2. Go to Connections -> WiFi -> WiFi Networks -> Open the current network and scroll down to the IP address

Then connect to the watch and install the app package:

```
# connect to the watch (it took me a number of tries and watch restarts to get it to connect and prompt me to accept the certificate to debug on my machine)
$ sdb connect 192.168.86.34:26101

# verify the watch is connected
$ sdb devices

# install the package
$ sdb install pulse.wgt
```

Some notes on debugging to the real devices, because it wasn't smooth:

* To connect to the device, you have to be on WiFi and turn off Bluetooth.
  * This would be fine, except that network functionality within the apps only seemed to work over Bluetooth.
  * So, I was constantly switching between Bluetooth and WiFi. Every time that I did switch, I had to reconfigure the WiFi, because it wouldn't connect
* To get the watch to connect through `sdb`, I was constantly having to restart it. It seemed like it would only connect after a cold boot.
  * I also had to run the `sdb connect` command multiple times, every time.
  * Even after I had authorized the certificate for my computer to debug to the device, it continued telling me that I needed to authorize it, which was just a faulty error message.

## Deploying the App

To launch the app:

1. Log in to your Samsung account: https://seller.samsungapps.com/
2. "Add New Application" -> "Wearable"
3. Fill in the required information. The error messages are a bit difficult to understand, but you can grind through them.

With Pulse, I had to provide credentials for a fake account, to test against.

To update the app:

1. Log in to your Samsung account: https://seller.samsungapps.com/
2. Open "Pulse SMS"
3. Hit the "Update" button near the top
4. Open the "Binary" tab.
5. Delete the current binary and upload the new version
6. "Save" -> "Submit"
