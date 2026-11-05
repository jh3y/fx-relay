# Acknowledgements

## tink-agent

FX Relay would not exist without [tink-agent](https://github.com/tajchert/tink-agent), by **Michal Tajchert**. That project demonstrated the FX-MIC's potential as a controller for agent workflows and provided the reference configuration that helped us investigate sample playback and pitch-based action banks. We are grateful for the work and for making it available to others.

FX Relay does not import or ship tink-agent's Python application or its sample recordings. The Swift application, diagnostic tooling, profiles and visual identity were developed for this project. Its focus is signal-to-action control, with speech handling left to the user's chosen application.

The cue WAVs and hardware JSON were generated locally. The configuration follows Teenage Engineering's documented format and uses tone frequencies and pitch settings studied in tink-agent. We credit that technical reference; matching settings and a shared technique do not by themselves establish that protected source material was copied.

The [upstream MIT license](https://github.com/tajchert/tink-agent/blob/main/LICENSE) is retained in [licenses/tink-agent-MIT.txt](licenses/tink-agent-MIT.txt) as reference material about the credited project, not as a declaration that tink-agent is a bundled dependency or that using its technique creates a license obligation. FX Relay's own license is [MIT](LICENSE).

## Hardware documentation and assets

The [Teenage Engineering EP-2350 guide](https://teenage.engineering/guides/ep-2350) informed the hardware configuration and firmware investigation.

The bridge implementation and vector artwork were developed for this project. The four cue WAVs are generated sine samples; no manufacturer sample recordings or firmware binaries are distributed. Apple frameworks and SF Symbols are used through their platform APIs.

Teenage Engineering, EP-2350, FX-MIC, Apple, Codex, Claude, MacWhisper, Superwhisper and Wispr Flow belong to their respective owners. Names identify hardware/software compatibility. This project is independent and does not imply sponsorship or a verified integration with those products.
