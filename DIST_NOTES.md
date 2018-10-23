# Tizen Build/Distribution Notes

These are notes for me on the build system and creating a signed build of the app, for the store. I have all of this set up on Jenkins to run automatically, but just in case I ever need to re-configure it...

I do all of this through the CLI SDK. The IDE is terrible.

## Building the App

#### Generate a signing certificate

Obviously I will need to continue to use the cert that I originally uploaded the app with, to sign for the store distribution. This is how I created it though.

```
$ tizen certificate -a PulseSMS -p <cert-password> -c US -s Iowa -ct Ankeny -o "Klinker Apps" -n "Luke Klinker" -e luke@klinkerapps.com -f pulse-tizen-cert
```

This generated a certificate in the `$TIZEN_SDK/tizen-studio-data/keysotre/author/pulse-tizen-cert.p12`.

#### Applying the signing cert to a security profile

After generating the signing cert, we apply it to a security profile. The profile just holds the information on the cert and the password. It is local to each machine and can be regenerated, as long as the cert is the same.

```
$ tizen security-profiles add -n PulseProfile -a $TIZEN_SDK/tizen-studio-data/keystore/author/pulse-tizen-cert.p12 -p <cert-password>
```

This generates the security profile on the machine, to sign the app.

#### Building a release version of the app

```
# build the Vue project and apply it to the Tizen app
$ cd web
$ npm install
$ npm run tizen

# build the Tizen web app
$ cd ../tizen
$ tizen cli-config "profiles.path=$TIZEN_SDK/tizen-studio-data/profile/profiles.xml"
$ tizen package -t wgt
```

## Deploying the App

TODO: I haven't deployed it yet.
