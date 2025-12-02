# Installing

## post-receive hook

Must be set either in target repos, or as a global config (core.hooksDir).

Specify an events folder, use the git user's env.

## monitor.sh

Runs every time a change is detected in the events folder. Picks any `.ini` in the repo, runs them.

You can of course run it locally, but you might want _some_ isolation, and run in Docker. If so, you can create a container using the script in `.build/run-gitomatic.sh`. You'll need to mount both the docker pipe file, and `/tmp` so that your containers use the same files.

# Using

## pipeline definition

Filter using filters in the `[filter]` section:
- `refs` to filter refs. Eg: `*/main`.
- `files` to filter only when change contains some files. **This is using grep so put in a regexp**. `*.cpp` won't work, use `.cpp` or `.*.cpp$` instead.

Define steps using the following keys:

### Docker

- `image`: name of image to execute. It must be a file.
- `script`: script to execute in the image.
- `artifacts`: a list of `;` separated artifacts, composed of name and the mounting point in the container separated by a `:`
- `env`: a list of environment variables to be passed to the container.

There are a few magic containers:
- `git`: repo root is mounted in folder `/repos`.

### Local tasks

🚨 local tasks run alongside your build script. You don't benefit from any isolation. If gitomatic doesn't run in a container, assume that anyone with write access to your repos will execute whatever they want. 

ENV variable `ALLOW_TASKS` must be set to `true`.

- `task` is the name of the task in the `tasks` folder.
- `parameters` is a set of parameters to be passed to the task.

## build script

Runs within docker. `REF` and `REPO` variable are defined by default. If there's an `env` file in the `build` folder of the bare repo, then it is passed as an env file to the container. Repo is mounted in the `/src` path.