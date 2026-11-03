# Security

Fanfic Engine's only network access is the update check (Sparkle, from GitHub; updates must be signed with the project's EdDSA key). The main risks are a malicious EPUB or PDF file that crashes the app or makes it write outside its library folder, and anything that could make the updater accept an update the project didn't sign.

If you find such a problem, please report it privately through GitHub's **Security → Report a vulnerability** on this repository instead of opening a public issue. Please include a description and, if possible, a minimal file that shows it.
