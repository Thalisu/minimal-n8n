# minimal-n8n

A low-memory n8n setup (SQLite, single process, aggressive execution pruning) sized for a machine with about 4 GB or less of free RAM.

There are two ways to run it, and they share the same `.env`:

| Host    | How                           | Why                                                                                                               |
| ------- | ----------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| Linux   | `linux/docker-compose.yml`    | Native containers, no VM overhead, hard memory limit via `mem_limit`.                                             |
| Windows | `windows\start-n8n.cmd` (npm) | Docker Desktop needs a WSL2 VM that costs 300-600 MB before n8n even starts. Running on Node directly skips that. |

The Docker Compose setup is for **Linux only**. Do not use it on Windows.

## Configuration

```sh
cp .env.example .env
```

Then set `N8N_ENCRYPTION_KEY` to a random value:

```sh
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

Back up this key. If you lose it, n8n cannot decrypt any stored credential.

On Windows, `windows\setup.cmd` does both steps for you.

## Linux (Docker Compose)

```sh
docker compose --env-file .env -f linux/docker-compose.yml up -d
```

Run it from the repository root. `--env-file` is required because Compose otherwise looks for `.env` next to the compose file.

- UI: <http://localhost:5678> (bound to 127.0.0.1 only)
- Data: the `n8n_data` Docker volume
- Files for the Read/Write Files nodes: `./local-files`, seen as `/files` inside n8n

## Windows (npm)

### Requirements

- **Node.js 24 or 26 LTS**. n8n 2.x requires Node 24 or newer, and the official Docker image runs on Node 26. The scripts accept only these two because `isolated-vm` ships prebuilt Windows x64 binaries for them. Other versions need Visual Studio Build Tools to compile it.

### Setup

Double-click `windows\setup.cmd`, or run it from a terminal. The script:

1. Installs Node.js 26 with winget when Node is missing. If a Node version other than 24 or 26 is installed, it stops and leaves it alone.
2. Creates `.env` from `.env.example` with a random `N8N_ENCRYPTION_KEY` when `.env` does not exist. An existing `.env` is never changed.
3. Installs `n8n@<N8N_VERSION>` globally with npm.

Without winget, install Node.js 26 LTS from <https://nodejs.org> and run the script again.

### Run

Double-click `windows\start-n8n.cmd`, or run it from a terminal. The script:

1. Loads `.env`.
2. Checks that the encryption key is set and that Node 24 or 26 is installed.
3. Installs `n8n@<N8N_VERSION>` globally with npm when it is missing or on a different version. To upgrade, change `N8N_VERSION` in `.env` and start the script again.
4. Applies the same memory limits as the Docker setup: 512 MB heap for the main process and 256 MB for the task runner.
5. Starts n8n and restarts it 10 seconds after it exits. Close the window to stop it.

- UI: <http://localhost:5678>
- Data: `.\data\.n8n` (SQLite database, settings, binary data)
- Files for the Read/Write Files nodes: `.\local-files`. Use the full Windows path in nodes.

### Start with Windows

Requirement: n8n has started at least once with `windows\start-n8n.cmd`. The script checks for `data\.n8n\database.sqlite`, which n8n creates on its first start, and refuses to register the task without it.

Run `windows\autostart.cmd`. It asks for administrator rights and for your Windows account password (a PIN does not work), then registers a scheduled task named `minimal-n8n` that runs `windows\start-n8n.cmd` at boot, before anyone logs in.

- The task has no window. Start it with `schtasks /run /tn minimal-n8n` and stop it with `schtasks /end /tn minimal-n8n`.
- Only one n8n runs at a time. `windows\start-n8n.cmd` refuses to start when its port is already in use, so opening it by hand while the task is running (or the other way round) prints a message and stops.
- Run `windows\autostart.cmd` again after you change your Windows password. The task stores the old one and stops starting.
- `windows\autostart.cmd remove` unregisters the task.

If n8n should start only after you log in, skip the task: press `Win+R`, type `shell:startup`, and create a shortcut to `windows\start-n8n.cmd` in that folder. In the shortcut properties, set **Run** to **Minimized**.

### Differences from Docker

- There is no hard memory cap on the process. Only the Node heap is limited.
- Code nodes run as your Windows user, without container isolation.

## Why npm (and not pnpm, Bun or Deno)

- **npm** is the install method n8n documents and supports.
- **pnpm** 10+ does not run dependency install scripts unless you approve them. `sqlite3` and `isolated-vm` need those scripts to set up their native binaries, so a plain `pnpm add -g n8n` installs a broken n8n. pnpm's strict `node_modules` layout can also break packages that rely on hoisting. pnpm saves disk space through deduplication, but that does not help much with a single global package.
- **Bun and Deno** cannot run n8n. `isolated-vm` is a native addon written against Node's V8 embedding API, and the task runner launches a separate `node` process anyway.

## Backup

Back up the `.env` file (it holds the encryption key) together with the data:

- Linux: the `n8n_data` volume
- Windows: the `data` folder
