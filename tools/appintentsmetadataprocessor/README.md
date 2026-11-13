# appintentsmetadataprocessor (prebuilt)

`linux-x86_64/appintentsmetadataprocessor` is a release build of
[re-appintentsmetadataprocessor](https://codeberg.org/viraptor/re-appintentsmetadataprocessor)
by Stanislaw Pitucha, an open-source reimplementation of the Xcode tool that generates `Metadata.appintents`.
It is used by `scripts/appintents.sh` and included here so that building Expenses only requires xtool.

- Version: 1.0.0 (commit `074d2f640773a35e4f25e0b19aa2658163f9e8ec`)
- Built with: `cargo build --release`
- SHA-256: `27dd915183848a64c460c99f58b367a5477c9e72a1478f1533d1b41d767ed958`
- License: MIT (as declared in the upstream `Cargo.toml`), copyright Stanislaw Pitucha

On other platforms, build it from source and point `APPINTENTS_PROCESSOR` to the binary:

```bash
git clone https://codeberg.org/viraptor/re-appintentsmetadataprocessor.git
cd re-appintentsmetadataprocessor
cargo build --release
export APPINTENTS_PROCESSOR="$PWD/target/release/appintentsmetadataprocessor"
```
