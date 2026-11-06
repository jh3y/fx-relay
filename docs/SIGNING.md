# Signing development builds

A stable signing certificate gives successive builds the same certificate-bound identity. This helps macOS recognise the app across updates instead of treating each ad-hoc build as new code. Keep the bundle identifier and the app’s installed location stable too. Permission retention is still controlled by macOS; the first transition from an ad-hoc build can require Microphone and Accessibility approval again.

## Local development on your Mac

```sh
python3 script/configure_signing.py --create-local
./script/build_and_run.sh --build-only
```

The explicit setup command creates **FX Relay Local Development** in your login Keychain. Its certificate is trusted in the user trust store for code signing only. Its private key is imported as non-extractable, with access granted to `/usr/bin/codesign`. Temporary key files are kept in an owner-only temporary directory and removed after import. macOS may ask for Keychain approval. Never share your login password or private key.

The selected public certificate fingerprint is saved in `.local/signing-identity.txt`, excluded from Git, snapshots and public exports. Running setup again reuses the existing valid identity. If a partial setup or duplicate certificate is found, it stops for review instead of creating more keys. Do not delete/recreate this identity on each build.

To remove the local build configuration, delete `.local/signing-identity.txt`. If you no longer need its identity, use Keychain Access to remove **FX Relay Local Development** and its associated private key from your login Keychain. This is separate from uninstalling the app. Removing the certificate affects future signing and may affect trust in builds signed with it.

## Existing signing identity

```sh
security find-identity -v -p codesigning
python3 script/configure_signing.py --identity YOUR_40_CHARACTER_FINGERPRINT
```

Alternatively, `FXMIC_SIGNING_IDENTITY` overrides the checkout’s selection. The build verifies that a configured identity is available before stopping the running app. It does not silently fall back to ad-hoc signing if your chosen identity is missing.

Without a configured identity, the build still uses ad-hoc signing and explains that permissions may need renewing. CI uses this route. No Keychain setup runs automatically during a build.

## Public distribution

Local self-signing is not Developer ID signing or notarization, and does not make the app trusted on someone else’s Mac. A public notarized binary requires Apple Developer credentials and a separate distribution process. The repository currently supports building your own copy. Local signing does not override managed-Mac policy or grant microphone/keyboard permissions.

The build keeps macOS’s certificate-bound designated requirement. It does not weaken that requirement, change TCC, or install a system-wide trust exception.
