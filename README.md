# OpenCampus-UE90min

Unreal Engine 5.7 sample game project for the open campus 90-minute class.

## Download the packaged game

- [Latest Windows Development build](../../releases/latest)

If the release asset is split into multiple `.7z.00*` files, download every part and open the `.001` file with [7-Zip](https://www.7-zip.org/).

## Release automation

Push a tag such as `v1.0.0` to package the project for Windows Development and publish the resulting archive to GitHub Releases.

The workflow runs on a self-hosted Windows runner with these prerequisites:

- The same home-PC self-hosted Windows runner label set used by Verseday/XroidVerse (`[self-hosted, windows]`)
- Unreal Engine 5.7 installed
- `UE_ROOT` environment variable pointing to the engine root
- `7z` available on `PATH`
