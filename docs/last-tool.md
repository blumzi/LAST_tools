# Managing LAST installations with `last-tool`

## Motivation

The *LAST* project runs on a large number of computers (currently 25 deployed: `last0` plus the
`last01e` … `last11w` and `last21e`/`last21w` units; `last-hosts --all` prints the full list).
Our hardware supplier pre-installs them with an "_Ubuntu 20.04 LTS Workstation_" distribution.

We consider this to be the **_basic_** installation, which needs to be elevated to an **_operational_** installation at
first deployment time and perpetually maintained afterwards.  Such an installation will allow the various *LAST* components
and subsystems to perform their tasks.

These requirements induce a highly repetitive and error prone set of administrative activities, specially when considering the large number of computers in the system.

## Policies

We define a **_LAST policy_** which defines **anything and everything** that differentiates  the **_operational_** installation from the **_basic_** installation.  For modularity and granularity it was split into _sections_, each with its own specific **_policy_**.

## Containers

A *LAST* container is a directory that contains components needed for a *LAST* installation, which cannot be installed via
the Internet.  The top directory contains a well defined list of subdirectories:

- `catalogs`: Contains the catalogs used by the *LAST* pipeline (`GAIA/DR3`, `MergedCat/V2`)
- `packages`: Contains packages that are not available via apt (nomachine, the QHY SDK, the Wine/CME2 disk)
- `matlab`: Contains original _Matlab_ installation area(s), used for silently installing the product (default release: *R2020b*)
- `files`: Contains site files that are not kept in git (e.g. `files/ssh` keys, `files/slack/env`)

### Finding the container

`last-tool` uses the first **valid** container along the *LAST_CONTAINER_PATH* environment variable (a `:`-separated list).
When it starts, it appends a container to that path, in this order of preference:

1. A mounted USB volume labeled *LAST-CONTAINER* (if found, nothing else is added)
2. On `last0`: `/last0/data2/LAST-CONTAINER`
3. On the units (10.23.1.x / 10.23.3.x): `/last0/LAST-CONTAINER` (automounted from `last0`), if it has a `catalogs` directory

A container can also be given explicitly through the environment, for example:

```bash
LAST_CONTAINER_PATH=/mnt/containers/central-container last-tool check matlab
```

This will look in the `/mnt/containers/central-container/matlab` directory for available _Matlab_ installations.

**NOTE**: the `-c|--container <path>` flag is accepted but currently has **no effect** (the container is selected
before the command line is parsed).  Use *LAST_CONTAINER_PATH* instead.

## The one `last-tool` to rule them all

The `last-tool` was conceived to fulfill the *LAST* policy.  It is designed to be used:

- At deployment-time to install and configure all the software components needed by the *LAST* project.
- Forever afterwards to maintain the *LAST* **_operational_** installation.
- On each and every one of the *LAST* computers.  At this point-in-time there is no central management software.

`check` and `enforce` must be run as root (e.g. `sudo last-tool check`).  `policy`, `list-sections` and the
informational flags can be run as any user.

### Usage

To get the help screen use: `last-tool --help`:

```none
    The LAST installation policy is anything and everything that differentiates a LAST installation
     from a vanilla Ubuntu installation (network, packages, matlab, LAST software, etc.)

    This tool either checks or makes (enforces) the LAST installation policy.

    Usage: last-tool [[flag] ...] <mode> [[section] ...]

     Flags:
     -h|--help:        show this help and exit
     -v|--version:     show version and exit
     -i|--info:        show info and exit
     -q|--quiet:       be silent (default: verbose)
     -n|--nodeps:      don't do section dependencies (default: dependant sections will be added)
     -c|--container:   select a LAST container (default: first valid container in LAST_CONTAINER_PATH, currently "...")

     Running <mode>:
      One running <mode> must be selected from the following (no default):
        check:                Checks if the current machine complies with the LAST installation policy
        enforce|make:         Enforces the LAST installation policy upon the current machine
        show-env|env:         Shows some information about the available installation resources
        show-policy|policy:   Prints out the LAST policy for the seected section(s)
        list-sections:        Just list all the available sections

     Sections:
      The workload is split into (possibly inter-dependant) sections.
      - To get a list of the defined sections run:
          $ last-tool list-sections
      - To select a subset of all the defined sections, just list them as arguments
         after the running <mode> (default: run all the defined sections)
```

`--help` then prints the per-section help of the sections that have their own flags (`last-software`, `matlab`, see below).

- `-v|--version` prints the installed `last-tool` package version (from `dpkg`).
- `-i|--info` prints the build info of the package (version, git repo, branch, commit, build time).
- Flags must come **before** the `<mode>`.  Section flags come right **after** their section name.

### Sections

The workload is split into a number of _sections_.  To get the currently defined list of _sections_, use: `last-tool list-sections`:

```none
[INFO]    Section              Description                                                      Requires
[INFO]    -------              -----------                                                      --------
[INFO]    apt                  Configures Apt                                                   profile network
[INFO]    bios                 Manages the machine's BIOS settings
[INFO]    catalogs             Handles the LAST catalogs                                        filesystems network
[INFO]    crontab              Handles crontabs
[INFO]    filesystems          Manages the exporting/mounting of filesystems                    network ubuntu-packages
[INFO]    hostname             Manages stuff related to the machine's host name
[INFO]    images               Handles LAST images
[INFO]    last-software        Manages our own LAST software                                    user ubuntu-packages
[INFO]    last-tool            Checks the installation of the last-tool package itself
[INFO]    logs                 Handles forwarding and rotation of the LAST logs and files
[INFO]    matlab               Manages the MATLAB installation                                  user apt last-software
[INFO]    network              Configures the LAST network
[INFO]    postgres             Maintains PostgreSQL on last0                                    network
[INFO]    profile              Manages profile files
[INFO]    sensors              Manages the LAST sensors                                         matlab
[INFO]    ssh                  Configures ssh client                                            user hostname ubuntu-packages
[INFO]    time                 Manages the LAST project time syncronization                     network
[INFO]    ubuntu-packages      Manages additional Ubuntu packages needed by LAST                apt
[INFO]    ubuntu-services      Stop and mask (disable) ubuntu services not needed by LAST       ubuntu-packages
[INFO]    user                 Manages the "ocs" user
```

At any given time `last-tool` can be invoked with any number of the pre-defined sections as arguments, for example:

```bash
sudo last-tool check last-software ubuntu-packages
```

Unless `-n|--nodeps` is given, the selected sections are expanded (in all modes) with their **direct** requirements
and run in dependency order.  Requirements are not followed recursively: `catalogs` adds `filesystems` and `network`,
but not the requirements of `filesystems`.

If no sections were specified, all the defined sections will be included.

### Section flags

#### `last-software`

```none
last-tool enforce|check|policy last-software -l|--list [-s|--space <name>]
    - lists the managed LAST software repositories

last-tool enforce last-software [[-r|--repo <repo>] ...] [-R|--reclone] [-s|--space <name>]
    - clones or pulls the specified repos (default: all repos)

 -l|--list         - list the LAST software repos
 -r|--repo <repo>  - add <repo> to the selected list (default: all repos)
 -R|--reclone      - discard local changes and re-clone the (selected) repos - DANGEROUS
 -e|--extras       - also handle the 'extras' (nomachine, the Wine disk, the QHY SDK, from the container)
 -s|--space <name> - use files/github-repos.<name> instead of files/github-repos
```

The available workspaces are the `files/github-repos.*` files (e.g. `production`, `rc`, `gledmagicwater`, `multimessenger`).

**NOTE**: `-ne|--no-extras` is listed in the section help but is currently rejected.

#### `matlab`

```none
last-tool check matlab -l|--list-releases
    - lists the matlab releases available in the LAST container

last-tool enforce matlab
    - installs the default matlab release (R2020b)
```

**NOTE**: `-r|--release <release>` is listed in the section help but is currently ignored; the default release is always used.

### Operation modes

`last-tool` has:

- Three main operation modes
  - `policy`: Prints out the **_LAST policy_** for the specified section(s)
  - `check`: Checks if the current installation fulfills the **_LAST policy_** for the specified section(s)
  - `enforce` (or `make`): Enforces the **_LAST policy_** for the specified section(s) upon the current installation
- Auxiliary operation modes
  - `list-sections`: Produces a list of the currently defined sections, with descriptions and requirements
  - `sections`: Just the section names, on one line (handy for scripts)
  - `show-env` (or `env`): Prints out some information about the current running environment
    (container path, installed/available Matlab, license file, section order, local MAC/IP/hostname)

A section that does not implement the selected mode is skipped with a warning.

### Messages

`last-tool` produces the following types of messages, labeled accordingly:

- `[INFO]` - Informative messages
- `[ OK ]` - Success messages
- `[WARN]` - Warning messages
- `[FAIL]` - Failure messages
- `FATAL`  - Fatal messages.  `last-tool` will terminate after producing such a message

Messages are logged to the system log (using `logger`) unless the environment variable `LAST_TOOL_DONTLOG` is set to `true`.
`check` and `show-env` never log.

## Scenarios

Here are a few possible usage scenarios.

### First-time installations

On a freshly delivered machine, with the `last-tool` package installed and a container reachable
(a *LAST-CONTAINER* USB volume, or `/last0/LAST-CONTAINER`):

```bash
sudo last-tool show-env        # verify the container, MAC/IP/hostname are found
sudo last-tool enforce         # all sections, in dependency order
sudo last-tool check           # verify
```

### Pulling the latest *LAST* software

```bash
sudo last-tool enforce last-software                      # all repos in files/github-repos
sudo last-tool enforce last-software -r matlab/AstroPack   # just one repo
sudo last-tool enforce last-software -s production         # use files/github-repos.production
```

Use `-n|--nodeps` (before the mode) to avoid also enforcing `user` and `ubuntu-packages`:

```bash
sudo last-tool -n enforce last-software
```
