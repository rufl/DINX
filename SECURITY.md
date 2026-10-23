# Security policy

DINX is a public alpha. Do not use it on systems or with data that cannot be restored.

## Supported scope

Security fixes target the current `main` branch and the latest documented alpha workflow output. Older ISO artifacts are not security-supported releases.

## Reporting a vulnerability

Do not open a public issue for an undisclosed vulnerability. Use GitHub's private vulnerability reporting form:

<https://github.com/rufl/DINX/security/advisories/new>

Include:

- affected commit, workflow run or artifact;
- host and guest architecture;
- exact reproduction steps;
- impact and required privileges;
- logs or a minimal proof of concept with secrets removed.

If private reporting is unavailable, contact the repository owner through the GitHub profile and do not publish the details until a fix or mitigation is coordinated.

## Alpha-specific boundaries

- The live image automatically opens the disposable `dinx` account in `Labwc (DINX)`; the public `dinx` password remains only as a diagnostic fallback if the greeter appears. Physical boot access already grants control of the live machine, so autologin is not an authentication boundary. Never reuse the password elsewhere.
- Verify the ISO checksum before writing removable media or booting it.
- Do not place production credentials, personal data or private keys in the live session.
- A successful boot is not evidence of production security, persistence safety or update safety.

See the [security model](docs/security-model.md) and [installation guide](docs/install.md) for operational guidance.
