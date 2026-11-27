# Installation and maintenance video script

**Limit:** 5 minutes. Target about 4 minutes. Use a clean checkout or label any machine-specific setup.

## Recording script and commands

### 0:00-0:35 - Repository

The source, documentation, tests, and GitHub Actions workflow are in `https://github.com/hassan36501/project`. CI runs on pushes and pull requests using Ubuntu. This is a prototype library; this repository does not deploy a production service.

### 0:35-1:20 - Clean machine prerequisites

Install Alire and its supported Ada toolchain for the operating system. On Windows, use the official Alire installer and open its Alire PowerShell shortcut. Confirm the command is available:

```powershell
where.exe alr
alr --version
```

The GitHub workflow installs Alire with `alire-project/setup-alire@v4` and installs the GNATprove crate for CI. CI runs on Ubuntu; do not claim Windows builds are CI-verified.

### 1:20-2:20 - Build and tests

From a clean checkout, resolve dependencies and build the library:

```sh
alr -n index --update-all
alr -n update
alr -n build
```

Build and run the test crate and RAM showcase:

```sh
cd tests
alr -n build
./bin/tests
cd ../showcase
alr -n build
alr -n run
```

In Windows PowerShell, use the generated `.exe` if present, for example `.\bin\tests.exe`. If `alr` is not found, setup is incomplete; an already-built executable is not evidence of a fresh build.

### 2:20-3:20 - File-device checks

The file-device test and demo are in `devices/file`. CI builds both GPR projects, then runs the programs from a temporary working directory so test data is isolated. On Ubuntu, follow `.github/workflows/ci.yml`. These checks do not test a real SD card, flash device, or physical power cut.

### 3:20-4:00 - CI, configuration, and upkeep

GitHub Actions runs on pushes and pull requests. The last verified successful run is linked in `docs/proof-status.md`. The workflow uses public Alire crates and does not require project secrets. Never show tokens, credentials, or private account settings in a recording.

To maintain the project, review pull requests, keep tests and CI green, and update `README.md`, `ARCHITECTURE.md`, and `docs/proof-status.md` when implementation or verification changes. Complete and review the open proof and hardware tasks before describing the project as production-ready.

**[On screen: presenter's exact name and confirmed contribution.]**
