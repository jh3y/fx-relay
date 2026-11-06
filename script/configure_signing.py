#!/usr/bin/env python3
"""Choose a code-signing identity, or explicitly create one for this Mac only."""
import argparse
from pathlib import Path
import re
import secrets
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
NAME = 'FX Relay Local Development'
CONFIG = ROOT / '.local' / 'signing-identity.txt'


def run(*args, **kwargs):
    return subprocess.run(args, check=True, capture_output=True, **kwargs).stdout


def identities():
    text = run('/usr/bin/security', 'find-identity', '-v', '-p', 'codesigning').decode()
    return dict(re.findall(r'\b([A-Fa-f0-9]{40}) "([^"]+)"', text))


def save(fingerprint):
    fingerprint = fingerprint.upper()
    known = identities()
    if fingerprint not in known:
        raise ValueError('This fingerprint is not a valid code-signing identity in your Keychain.')
    CONFIG.parent.mkdir(mode=0o700, exist_ok=True)
    CONFIG.write_text(fingerprint + '\n')
    print(f'Configured {known[fingerprint]} for this checkout. Identity: {fingerprint}')
    print('The private key stays in Keychain. This local setting is excluded from exports and version control.')


def create_local():
    matching = [fingerprint for fingerprint, name in identities().items() if name == NAME]
    if len(matching) == 1:
        save(matching[0])
        return
    if matching:
        raise ValueError('Multiple local identities exist. Select a fingerprint with --identity.')
    # Do not create a second key after an interrupted import/trust operation.
    existing = subprocess.run(['/usr/bin/security', 'find-certificate', '-c', NAME], capture_output=True)
    if existing.returncode == 0:
        raise ValueError('A certificate with this name already exists but is not a valid identity. Review it in Keychain Access before retrying.')
    keychain = Path.home() / 'Library/Keychains/login.keychain-db'
    if not keychain.is_file():
        raise ValueError('No login Keychain found. Create/select a signing identity with Keychain Access.')
    with tempfile.TemporaryDirectory(prefix='fx-relay-signing-') as temporary:
        work = Path(temporary)  # mkdtemp is owner-only; private material never enters the repo.
        config = work / 'certificate.cnf'
        key = work / 'private.pem'
        certificate = work / 'certificate.pem'
        identity = work / 'identity.p12'
        config.write_text(f'''[req]
distinguished_name = subject
x509_extensions = signing
prompt = no
[subject]
CN = {NAME}
[signing]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
subjectKeyIdentifier = hash
''')
        run('/usr/bin/openssl', 'req', '-new', '-x509', '-newkey', 'rsa:3072', '-nodes',
            '-sha256', '-days', '3650', '-config', str(config), '-keyout', str(key), '-out', str(certificate))
        key.chmod(0o600)
        # Keychain's PKCS#12 importer on recent macOS rejects empty passphrases.
        # Use a disposable random wrapping password, never a user's password.
        # It is not logged or saved; the owner-only temporary files are removed.
        wrapping_password = secrets.token_hex(32)
        run('/usr/bin/openssl', 'pkcs12', '-export', '-inkey', str(key), '-in', str(certificate),
            '-out', str(identity), '-name', NAME, '-passout', 'stdin', input=(wrapping_password + '\n').encode())
        identity.chmod(0o600)
        # Import a non-extractable key, authorising only codesign rather than all apps.
        run('/usr/bin/security', 'import', str(identity), '-k', str(keychain), '-f', 'pkcs12',
            '-x', '-P', wrapping_password, '-T', '/usr/bin/codesign')
        # User trust, constrained to code signing. No system trust store/TCC changes.
        run('/usr/bin/security', 'add-trusted-cert', '-r', 'trustRoot', '-p', 'codeSign',
            '-k', str(keychain), str(certificate))
        fingerprint = run('/usr/bin/openssl', 'x509', '-in', str(certificate), '-noout', '-fingerprint', '-sha1')
        save(fingerprint.decode().strip().split('=')[-1].replace(':', ''))
    print('Local certificate created. This is not Developer ID signing or notarization.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--create-local', action='store_true', help='Create a local code-signing certificate and private key in the login Keychain.')
    group.add_argument('--identity', help='Use an existing valid 40-character SHA-1 identity fingerprint.')
    args = parser.parse_args()
    try:
        if args.create_local:
            create_local()
        else:
            if not re.fullmatch(r'[A-Fa-f0-9]{40}', args.identity):
                raise ValueError('Use the 40-character fingerprint from security find-identity -v -p codesigning.')
            save(args.identity)
    except subprocess.CalledProcessError as error:
        parser.exit(1, 'Signing setup stopped: ' + error.stderr.decode(errors='replace') + '\n')
    except (OSError, ValueError) as error:
        parser.exit(1, f'Signing setup stopped: {error}\n')
