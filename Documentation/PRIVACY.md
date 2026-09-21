# Privacy and local storage

Onde's native sound engine runs locally. No account, subscription, cloud-generation service, telemetry or listening-history upload is required.

Your settings, session history, daily activity ledger and imported audio are stored under `~/Library/Application Support/Onde/`, separate from the app and source repository. The activity ledger records session-running time, not screen content, keyboard input, health data or inferred concentration. Imported filenames, custom mix names and personal provenance are preserved rather than translated.

The optional update checker contacts GitHub's public release API. GitHub receives normal network information such as your IP address and the app's User-Agent. Personal history, preferences and imported audio are not sent. Automatic checks can be disabled in Updates. Downloading and installing an update require separate, explicit approval. Downloads are checked for size and SHA-256 integrity. Install and Relaunch rechecks a private copy, validates bundle identity, code signature, build, architecture and archive paths, then uses a short-lived same-user helper to replace the app and reopen it. No launch agent, privileged service or background installation is created. The helper never contacts the network, exports signing keys, changes macOS security settings or touches listening data. The previous application is retained until launch is confirmed.

Onde has no embedded online audio or video player. Local sound generation and personal audio imports do not contact streaming services.

The CLI communicates over an owner-only UNIX socket, not a network port. Any process running as your macOS user may have the same access as that user; this is local user isolation, not an app-by-app security boundary. Do not run untrusted code as your user.

Public builds contain no private library data. Review screenshots and diagnostic logs before sharing: custom names, file paths and history may be personal. Deleting the app alone leaves your personal library in place. Back it up before manually deleting local data.
