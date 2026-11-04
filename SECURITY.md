# Security Policy

Mop deletes files, so safety bugs are taken seriously.

## What counts as a security or safety issue

- Mop removes, or offers to remove, files it shouldn't, such as system files, another app's data,
  or user documents matched by mistake.
- A way to make Mop delete arbitrary paths, for example through crafted folder or app names or symlinks.
- Anything that bypasses `SafetyGuard` or the Trash (permanent deletion outside *Empty Trash*).

## Reporting

Please **don't open a public issue** for these. Report them privately through
[GitHub Security Advisories](https://github.com/luanpanno/mop/security/advisories/new).

Include your macOS version, your Mop version, and the steps or paths involved. You'll get a reply as soon
as possible, and a fix will be released before any details are made public.

## Supported versions

Only the latest release gets fixes.
