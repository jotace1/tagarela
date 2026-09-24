# Local signing

`scripts/bundle.sh` signs with the identity in `TAGARELA_SIGN_IDENTITY` (default:
`Tagarela Local`). This matters more than it looks: macOS ties privacy
permissions to the app's signature, and an ad-hoc signature
(`codesign --sign -`) produces a new hash on every build — the system treats
each rebuild as a different app and asks for microphone, screen and
accessibility access again, every time.

To create a stable local identity, once:

```sh
openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 3650 \
  -nodes -subj "/CN=Tagarela Local" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=critical,codeSigning" \
  -addext "basicConstraints=critical,CA:false"
openssl pkcs12 -export -legacy -out cert.p12 -inkey key.pem -in cert.pem \
  -passout pass:yourpassword -name "Tagarela Local"
security import cert.p12 -k ~/Library/Keychains/login.keychain-db \
  -P yourpassword -T /usr/bin/codesign
security add-trusted-cert -r trustRoot -p codeSign \
  -k ~/Library/Keychains/login.keychain-db cert.pem
```

Or export `TAGARELA_SIGN_IDENTITY` with an Apple Development identity you already
have.

Without `keyUsage=digitalSignature` the certificate imports fine but
`codesign` answers "no identity found", and `security find-identity -p
codesigning` lists it as "Invalid Key Usage for policy".

None of this is notarization: the build is not signed with an Apple Developer
ID, so a download from the browser is still blocked by Gatekeeper.
