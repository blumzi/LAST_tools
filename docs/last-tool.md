# Managing LAST installations with `last-tool`

## Motivation

The *LAST* project runs on a large number of computers (actually 25).  Our hardware supplier pre-installs them
with an "_Ubuntu 20.04.03 LTS Workstation_" distribution.

We consider this to be the **_basic_** installation, which needs to be elevated to an **_operational_** installation at
first deployment time and perpetually maintained afterwards.  Such an installation will allow the various *LAST* components
and subsystems to perform their tasks.

These requirements induce a highly repetitive and error prone set of administrative activities, specially when considering the large number of computers in the system.

## Policies

We define a **_LAST policy_** which defines **anything and everything** that differentiates  the **_operational_** installation from the **_basic_** installation.  For modularity and granularity it was split into _sections_, each with its own specific **_policy_**.

## Containers

A *LAST* container is a directory that contains components needed for a *LAST* installation, which cannot be installed via
the Internet.  The top directory contains a well defined list of subdirectories:

- `catalogs`: Contains the catalogs used by the *LAST* pipeline
- `packages`: Contains some packages that are not available via use of apt. These include the `last-tool` package itself.
- `matlab`: Contains original _Matlab_ installation area(s), used for silently installing the product (currently only *R2020b*)

### The default container

`last-tool` will use the first **valid** container along the *LAST_CONTAINER_PATH* environment variable.

Assuming that a **valid** container has been manually mounted onto `/mnt/containers/central-container`, one can run:

```bash
LAST_CONTAINER_PATH=/mnt/containers/central-container last-tool check matlab
```

This will look in the `/mnt/containers/central-container/matlab` directory for available _Matlab_ installations.

**NOTE**:

&nbsp;&nbsp;&nbsp;&nbsp;If a USB storage device, labeled *LAST-CONTAINER*, is currently mounted (by default onto `/media/ocs/LAST-CONTAINER`) it will be automatically appended to the *LAST_CONTAINER_PATH*.

### Specifying a container

A container can be specified to `last-tool` (see below) by passing the respective flag, as in:

```bash
last-tool --container /mnt/containers/central-container check matlab
```

## The one `last-tool` to rule them all

The `last-tool` was conceived to fulfill the *LAST* policy.  It is designed to be used:

- At deployment-time to install and configure all the software components needed by the *LAST* project.
- Forever afterwards to maintain the *LAST* **_operational_** installation.
- On each and every one of the *LAST* computers.  At this point-in-time there is no central management software.

### Usage

To get the help screen use: `last-tool --help`:

```none
    The LAST installation policy is anything and everything that differentiates a LAST installation
     from a vanilla Ubuntu installation (network, packages, matlab, LAST software, etc.)

    This tool either checks or enforces the LAST installation policy.

    Usage: last-tool [-q|--quiet] [-n|--nodeps] [-c|--container <path>] <mode> [[section] ...] 
           last-tool -h|--help

     -q|--quiet:       be silent (default: verbose)
     -n|--nodeps:      don't do section dependencies (default: dependant sections will be added)
     -c|--container:   select a LAST container (default: first valid container in LAST_CONTAINER_PATH, currently "")

     Running <mode>:
      One running <mode> must be selected from the following (no default):
        check:                Checks if the current machine complies with the LAST installation policy
        enforce:              Enforces the LAST installation policy upon the current machine
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

### Sections

The workload is split into a number of _sections_.  To get the currently defined list of _sections_, use: `last-tool list-sections`:

```none
[INFO]    Section              Description                                                      Requires
[INFO]    -------              -----------                                                      --------
[INFO]    apt                  Configures Apt                                                   
[INFO]    bios                 Manages the machine's BIOS settings                              
[INFO]    catalogs             Handles the LAST catalogs                                        filesytems
[INFO]    filesystems          Manages the exporting/mounting of filesystems                    network ubuntu-packages
[INFO]    hostname             Manages stuff related to the machine's host name                 
[INFO]    last-software        Manages our own LAST software                                    user
[INFO]    matlab               Manages the MATLAB installation                                  user
[INFO]    network              Configures the LAST network                                      
[INFO]    profile              Manages profile files                                            
[INFO]    time                 Manages the LAST project time syncronization                     network
[INFO]    ubuntu-packages      Manages additional Ubuntu packages needed by LAST                apt
[INFO]    user                 Manages the "ocs" user 
```

At any given time `last-tool` can be invoked with any number of the pre-defined sections as arguments, for example:

```bash
last-tool check last-software ubuntu-packages
```

Before running in the `check` operational mode, the list of sections will be expanded to include the respective requirements.

If no sections were specified, all the defined sections will be included.

### Operation modes

`last-tool` has:

- Three main operation modes
  - `policy`: Prints out the **_LAST policy_** for the specified section(s)
  - `check`: Checks if the current installation fulfills the **_LAST policy_** for the specified section(s)
  - `enforce`: Enforces the **_LAST policy_** for the specified section(s) upon the current installation
- Two auxiliary operation modes
  - `list-sections`: Produces a list of the currently defined sections
  - `show-env`: Prints out some information about the current running environment

### Messages

`last-tool` produces the following types of messages, labeled accordingly:

- `[INFO]` - Informative messages
- `[ OK ]` - Success messages
- `[WARN]` - Warning messages
- `[FAIL]` - Failure messages
- `FATAL`  - Fatal messages.  `last-tool` will terminate after producing such a message

All the messages are logged to the system log (using `logger`) unless the environment variable `LAST_TOOL_DONTLOG` is set to `true`

## Scenarios

Here are a few possible usage scenarios.

### First-time installations

### Pulling the latest *LAST* software
