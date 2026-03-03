# Gitomatic CI/CD — Instructions for Claude

This repository uses **Gitomatic**, a lightweight Git-based CI/CD system. Pipelines are defined as `.ini` files in the `.build/` directory and run automatically when code is pushed.

## Pipeline file format

Pipeline files are INI files located in `.build/*.ini`. They are parsed from the Git tree at the pushed ref, so they must be committed.

### Structure

```ini
# Comments start with #

[filter]
    refs=<glob pattern>
    files=<grep regex>

[step name]
    <key>=<value>
```

- The `[filter]` section is optional and controls when the pipeline runs.
- All other sections are execution steps, run sequentially in order.
- Section names can contain spaces (e.g., `[build image]`).
- Indentation uses tabs or spaces — both work.

### Filter section

| Key     | Description | Example |
|---------|-------------|---------|
| `refs`  | Glob pattern matched against the pushed Git ref. | `refs/heads/main`, `refs/tags/*`, `*/main` |
| `files` | **Grep regex** (not glob!) matched against changed file paths. | `.cpp`, `\.md$`, `Dockerfile` |

Both filters must pass for the pipeline to run. If omitted, the pipeline always runs.

**Important:** `files` is a grep regex. `*.cpp` won't work — use `.cpp` or `.*.cpp$` instead.

### Step types

Each step section must contain exactly one of: `image`, `task`, `repo`, or `pipeline`.

#### 1. Docker image step (`image`)

Runs a command in a Docker container. The repository is cloned and mounted at `/src` (or custom `workdir`).

| Key          | Required | Description |
|--------------|----------|-------------|
| `image`      | Yes      | Docker image name/tag to run. |
| `script`     | No       | Script path (relative to repo root) to execute in the container. If omitted, the image's default entrypoint is used. |
| `artifacts`  | No       | Semicolon-separated `name:/container/path` pairs. Creates a temporary host folder mounted at the given path, shared across steps by name. |
| `env`        | No       | Environment variables, separated by literal `\n`. E.g., `FOO=bar\nBAZ=qux`. |
| `workdir`    | No       | Working directory in the container. Default: `/src`. |
| `entrypoint` | No       | Path to a custom entrypoint script. |
| `mount`      | No       | Semicolon-separated `/host/path:/container/path` pairs for additional volume mounts. |

The special image `build-docker-image` automatically gets the Docker socket mounted, enabling Docker-in-Docker builds.

**Built-in environment variables** available in containers:
- `REF` — the Git ref being built (e.g., `refs/heads/main`)
- `REPO` — the repository path

**Environment file:** if a `build/env` file exists in the bare repo, it is automatically passed as `--env-file` to all containers. Manage it with `git build env set KEY=VALUE` / `git build env ls`.

#### 2. Local task step (`task`)

Runs a script from Gitomatic's `tasks/` directory on the host. Requires `ALLOW_TASKS=true` on the Gitomatic server.

| Key          | Required | Description |
|--------------|----------|-------------|
| `task`       | Yes      | Task name (filename in Gitomatic's `tasks/` folder). |
| `parameters` | No       | Space-separated arguments passed to the task. |

#### 3. Additional repository step (`repo`)

Clones another repository from the same server as an artifact, making it available to subsequent steps.

| Key        | Required | Description |
|------------|----------|-------------|
| `repo`     | Yes      | Relative path to the repository (relative to the server's repo root). |
| `artifact` | Yes      | Artifact name — subsequent steps can mount this via `artifacts`. |
| `revision` | No       | Branch, tag, or commit to check out. |

#### 4. Trigger another pipeline (`pipeline`)

Triggers a pipeline in another (or the same) repository. Failures propagate to the parent.

| Key        | Required | Description |
|------------|----------|-------------|
| `pipeline` | Yes      | Format: `repo_path:pipeline_file.ini:ref`. E.g., `myapp:.build/deploy.ini:refs/heads/main`. |

## Examples

### Basic build on push to main

```ini
[filter]
    refs=refs/heads/main

[build]
    image=node
    script=.build/build.sh
```

### Build with artifacts shared between steps

```ini
[filter]
    refs=refs/heads/main

[build]
    image=node
    artifacts=dist:/src/dist
    script=.build/build.sh

[deploy]
    image=aws-cli
    artifacts=dist:/data
    script=.build/deploy.sh
```

### Build a Docker image (using build-docker-image)

```ini
[filter]
    refs=refs/heads/main
    files=Dockerfile

[build image]
    image=build-docker-image
    script=.build/docker-build.sh
```

Where `.build/docker-build.sh` would be:

```bash
#!/bin/bash
docker build . -t my-image-name
```

### Tag-triggered pipeline with file filter

```ini
[filter]
    refs=refs/tags/*
    files=\.txt$

[build]
    image=my-image
    script=.build/build.sh
```

### Pipeline with environment variables

```ini
[filter]
    refs=refs/heads/main

[build]
    image=node
    env=NODE_ENV=production\nCI=true
    script=.build/build.sh
```

### Trigger another repo's pipeline

```ini
[filter]
    refs=refs/heads/main

[deploy]
    pipeline=infrastructure:.build/deploy.ini:refs/heads/main
```

## Build scripts

Build scripts are regular shell scripts. They run inside the Docker container with the repo mounted at `/src` (default). Keep them in `.build/` alongside the pipeline `.ini` files. Make sure they are executable (`chmod +x`).

```bash
#!/bin/bash
# .build/build.sh
npm install
npm run build
```

## Client commands

From a local clone with an SSH remote, these commands are available:

- `git build run [--ref <ref>] [--watch]` — manually trigger a build
- `git build logs last [--watch]` — view latest build log
- `git build env set KEY=VALUE` — set a build environment variable
- `git build env ls` — list build environment variable names

## When creating or modifying pipelines

1. Place `.ini` files in `.build/` — Gitomatic discovers all `.build/*.ini` files automatically.
2. Place build scripts in `.build/` — keep everything together.
3. Make build scripts executable and start with `#!/bin/bash`.
4. Use the `[filter]` section to avoid unnecessary runs.
5. Remember `files` uses **grep regex**, not glob patterns.
6. Artifacts are shared across steps by name — use the same artifact name in multiple steps to pass data between them.
7. Each step either succeeds or terminates the entire pipeline.
8. Pipeline files must be committed and pushed — they are read from the Git tree, not the working directory.
