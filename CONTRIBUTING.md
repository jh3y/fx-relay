# Contributing

Start with the [architecture and build guide](docs/DEVELOPMENT.md). Keep changes small and explain the observed hardware behavior or user problem they address.

The bridge must remain a controller: no speech recognition, transcription service, audio routing or LLM connection. Keep signal processing off the main thread, visible UI updates bounded, and key releases independent of UI stalls. Never add repeated keyDown events to generic Hold Key behavior.

Hardware reports should identify app/firmware version, audio adapter, FX light position, sample slot and exact press sequence. Distinguish measured behavior from predictions. Use preview with output off first. Review exported logs before sharing them, since customized profile commands may appear in a report. Do not include microphone audio, device backups, credentials or unrelated terminal contents.

Run the relevant Swift/Python tests and a native layout/interaction check for UI changes. The GitHub workflow runs the tests and builds a development app. Contributions to FX Relay are provided under the project's [MIT license](LICENSE); preserve third-party copyright and license notices when including others' work.
