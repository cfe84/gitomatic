
## post-receive hook

Must be set either in target repos, or as a global config (core.hooksDir).

Specify an events folder, use the git user's env.

## monitor.sh

Runs every time a change is detected in the events folder. Picks any `.ini` in the repo, runs them.

## pipeline definition

Filter using filters in the `[filter]` section:
- `refs` to filter refs. Eg: `*/main`.
- `files` to filter only when change contains some files. **This is using grep so put in a regexp**. `*.cpp` won't work, use `.cpp` or `.*.cpp$` instead.

Define steps using the following keys:

- `image`: name of image to execute. It must be a file.
- `script`: script to execute in the image.
- `artifacts`: an artifact name, and the mounting point in the container

## build script

Runs within docker. `REF` and `REPO` variable are defined by default. If there's an `env` file in the `build` folder of the bare repo, then it is passed as an env file to the container. Repo is mounted in the `/src` path.