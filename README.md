# kubespary-offline-file-image-list

## Overview

This project automates the process of collecting all required files and container images for each release of [kubespray](https://github.com/kubernetes-sigs/kubespray). It is designed to help users prepare for offline Kubernetes cluster installation by generating versioned lists of files and images, and provides scripts for batch downloading them.

## Features

- **Automatic clone and update of kubespray repository**
- **Iterate all kubespray releases** and run the official `contrib/offline/generate_list.sh` script for each release
- **Generate versioned files.list and images.list** for every release, stored in `files.list/` and `images.list/` directories
- **Batch download scripts** for all required files and images, supporting multiple container runtimes
- **Python virtual environment and dependency management** via [uv](https://github.com/astral-sh/uv)

## Directory Structure

```bash
.
├── generate_list.sh         # Main automation script
├── download-releases.sh     # Batch download all files for all releases
├── download-images.sh       # Batch download all images for all releases
├── files.list/              # Output: files.list for each kubespray release (e.g. v2.28.0.list)
├── images.list/             # Output: images.list for each kubespray release (e.g. v2.28.0.list)
├── kubespray/               # Cloned kubespray repository (auto-managed)
├── .venv/                   # Python virtual environment (auto-managed)
├── pyproject.toml           # Python dependencies
└── ...
```

## Requirements

- [uv](https://github.com/astral-sh/uv) (auto-installed if missing)
- Python 3.12+
- Git
- curl
- Docker / Podman / nerdctl (for image download)

## Quick Start

**Set the `REGISTRY_PREFIX` variable in `download-images.sh` to your registry prefix.**

```bash
REGISTRY_PREFIX="your-registry.com"
```

**Generate all files.list and images.list for every kubespray release:**

```bash
bash generate_list.sh
```

This will:

- Ensure `uv` and Python virtual environment are ready
- Clone or update the kubespray repo
- For each release, run `contrib/offline/generate_list.sh`
- Copy the generated `files.list` and `images.list` to the root `files.list/` and `images.list/` directories, named by release version

**Download all required files for all releases:**

```bash
bash download-releases.sh
```

   This will read all `*.list` files in `files.list/` and download the files to `releases/`.

**Download and retag all required images for all releases:**

```bash
bash download-images.sh
```

This will read all `*.list` files in `images.list/` and pull/tag/push images to your registry (default: `registry.i.jimyag.com`).

## Customization

- You can change the registry prefix in `download-images.sh` by editing the `REGISTRY_PREFIX` variable.
- The scripts support Docker, Podman, and nerdctl for image operations.

## Dependencies

Python dependencies are managed in `pyproject.toml` and will be installed automatically via `uv`.

## License

This project is based on and interacts with [kubespray](https://github.com/kubernetes-sigs/kubespray), which is licensed under the Apache-2.0 license.
