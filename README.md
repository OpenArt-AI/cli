# OpenArt CLI

Make images and video with [OpenArt](https://openart.ai), from your terminal.

`openart` puts your OpenArt account on the command line. Describe what you want,
pick a model, and the result comes back in the same window — as a link you can
share, or a file saved straight to your computer.

It is one file to install and nothing else to set up: no Python, no Node, no API
keys to copy and paste. Sign in once through your browser and you are ready.

```sh
openart login
openart generate image "a red fox in the snow" --model nano-banana-2
openart generate video "a paper boat drifting down a rain gutter" --model kling-3-omni
```

## What you can do

- **Make an image from a description.** Give it a sentence and a model, and get
  a picture back.
- **Change an image you already have.** Point it at a photo on your computer or
  a link, and describe the edit — make it snowy, restyle it, move it somewhere
  else entirely.
- **Make a video from a description, or bring a still photo to life.** Where the
  model allows it, you choose the length, the shape and the resolution.
- **See what anything costs before you spend a credit.** List every model
  available to you, compare prices cheapest-first, and check exactly which
  settings a particular model accepts.
- **Keep the results.** Print a link, or download straight into a folder.
- **Look back over everything you have made.** Check on a job that is still
  running, or wait for it to finish.
- **Stay organised.** Switch between projects and workspaces, and upload
  reference images once to reuse them later.
- **Check your plan and credit balance** whenever you like.
- **Let a program drive it.** Every command can return plain data instead of a
  table, so scripts, pipelines and AI agents can use it as easily as you can.

Model names change as new ones arrive — run [`openart model
list`](#finding-models-and-what-they-cost) to see everything available to you
today.

## Contents

- [Install](#install) — [macOS and Linux](#macos-and-linux) ·
  [Windows](#windows) · [Manual download](#manual-download) ·
  [Upgrading](#upgrading)
- [Getting started](#getting-started) — signing in, and checking your credits
- [Generating images and video](#generating-images-and-video) — text to image,
  image to image, text to video, animating a photo
- [Finding models, and what they cost](#finding-models-and-what-they-cost) —
  what is available, what it accepts, what it charges
- [History, projects, and uploads](#history-projects-and-uploads) — past
  results, organising work, reference images
- [Scripting and agents](#scripting-and-agents) — plain data out, and a safe
  way to rehearse a request
- [Uninstall](#uninstall)
- [Support](#support) · [License](#license)

## Install

### macOS and Linux

```sh
curl -fsSL https://raw.githubusercontent.com/OpenArt-AI/cli/main/install.sh | sh
```

The installer picks the right build for your machine, verifies it against the
release checksums, and installs to `/usr/local/bin` — or to `~/.local/bin` if
that is not writable, rather than prompting you for `sudo` unexpectedly.

```sh
# install somewhere specific
curl -fsSL .../install.sh | sh -s -- --prefix "$HOME/.local"

# pin an exact version
curl -fsSL .../install.sh | sh -s -- --version 0.1.0
```

### Windows

```powershell
irm https://raw.githubusercontent.com/OpenArt-AI/cli/main/install.ps1 | iex
```

Installs to `%LOCALAPPDATA%\Programs\openart\bin` and adds it to your user
`PATH` — no administrator rights required. A piped script cannot take
parameters, so to pin a version set an environment variable first:

```powershell
$env:OPENART_VERSION = '0.1.0'
irm https://raw.githubusercontent.com/OpenArt-AI/cli/main/install.ps1 | iex
```

### Manual download

Grab the archive for your platform from the
[latest release](https://github.com/OpenArt-AI/cli/releases/latest), extract it,
and put `openart` somewhere on your `PATH`.

| Platform | Asset |
| --- | --- |
| macOS, Apple silicon | `openart_<version>_darwin_arm64.tar.gz` |
| macOS, Intel | `openart_<version>_darwin_amd64.tar.gz` |
| Linux, x86-64 | `openart_<version>_linux_amd64.tar.gz` |
| Linux, arm64 | `openart_<version>_linux_arm64.tar.gz` |
| Windows, x86-64 | `openart_<version>_windows_amd64.zip` |
| Windows, arm64 | `openart_<version>_windows_arm64.zip` |

Every release ships a `checksums.txt`. Verify your download with:

```sh
shasum -a 256 -c checksums.txt --ignore-missing
```

### Upgrading

Re-run the installer — it overwrites the existing binary in place.

## Getting started

```sh
openart login       # opens your browser; no API key to copy and paste
openart account     # confirms who you are, your plan, and your credit balance
```

`login` uses the standard OAuth browser flow with PKCE. The credential is stored
at `~/.openart/cli-credentials.json` (mode `0600`) — or
`%USERPROFILE%\.openart\cli-credentials.json` on Windows — and refreshed
automatically. `openart logout` revokes it and clears local state.

## Generating images and video

Media is always explicit in the command — `generate image` or `generate video` —
so an image request can never be routed to a pricier video model by accident.

```sh
# text to image
openart generate image "a red fox in the snow" --model nano-banana-2

# image to image: a local file, or a URL already on https://cdn.openart.ai
openart generate image "make it snowy" --model nano-banana-2 --image ./fox.png

# download the result instead of just printing its URL
openart generate image "neon city" --model gpt-image-2 -o ./out/

# text to video, and image to video
openart generate video "timelapse of a blooming flower" --model kling-3-omni \
  --duration 8 --aspect-ratio 16:9 --resolution 720p
openart generate video "slow zoom in" --model kling-3-omni --image ./photo.jpg
```

Each command submits the job, polls until it finishes (bounded by `--timeout`,
default 5 minutes), and prints the result. Pass `--async` to skip the wait: the
command submits, prints the generation's id, and exits, leaving you to pick the
result up later with `openart creation wait <id>`. `--duration`, `--aspect-ratio`, and
`--resolution` are model-specific — omit them to take the model's own defaults.

## Finding models, and what they cost

```sh
openart model list                          # every model, and the modes it supports
openart model cost                          # price everything, cheapest first
openart model cost --model <id> --mode text2image
openart model form <id> text2image          # exactly which parameters that model takes
```

`model cost` never spends credits — it only quotes them.

## History, projects, and uploads

```sh
openart creation list --type video --limit 10
openart creation get <id>                   # status and result URLs
openart creation wait <id>                  # block until it finishes

openart project list
openart project create --name "My Project"
openart workspace list                      # the active one is marked *
openart workspace select <workspace-id>
openart workspace select                    # back to your personal workspace

openart upload add ./reference.png          # prints a URL to use in a generation
openart upload list --type image
```

## Scripting and agents

Three flags make the CLI safe to drive from a program:

- **`--json`** — every command emits machine-readable JSON on stdout. Pagination
  cursors and progress go to stderr, so a pipe stays clean.
- **`--dry-run`** — every command that writes or spends credits prints the exact
  request it *would* send, then exits 0.
- **`--async`** — `generate` submits and returns immediately, printing the
  generation's id instead of waiting for the result. Pick it up whenever you
  like with `creation wait` / `creation get`, so a slow video does not pin a
  process open. Not combinable with `-o/--output`, which needs a finished
  generation to download.

```sh
openart generate image "test" --model nano-banana-2 --dry-run

# submit now, collect later
id=$(openart generate video "a paper boat" --model pixverseV6 --async)
openart creation wait "$id"

openart model cost --json | jq -r '.items[] | "\(.model)\t\(.totalCredits)"'
openart creation list --json --limit 5 | jq -r '.data[].url'
```

Commands exit non-zero on failure and print the reason to stderr.

Run `openart --help`, or `openart <command> --help`, for the full surface.

## Uninstall

```sh
rm "$(command -v openart)"
rm -rf ~/.openart          # also removes the stored credential
```

On Windows, delete `%LOCALAPPDATA%\Programs\openart` and remove it from your
user `PATH`, then delete `%USERPROFILE%\.openart`.

## Support

Bugs and feature requests: [open an issue](https://github.com/OpenArt-AI/cli/issues).

Include the output of `openart version` — it reports the exact build, platform,
and commit.

## License

The `openart` binaries are distributed under the [MIT License](LICENSE).
