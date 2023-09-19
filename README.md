# Amnesia.

## Introduction

Amnesia is a simple bash script that works as your executable scripts repository.
It's dedicated for anyone who can't remember all those fancy linux commands.

## Installation

### Local usage

You can just download `amnesia` and use it from the directory you are currently
in:

```
curl https://ofca.github.io/amnesia -O && chmod +x amnesia
```

Then just execute:

```
./amnesia
```

### Global usage

If you want to be able to use amnesia from anywhere in your system:  

```
curl https://ofca.github.io/amnesia -o /usr/local/bin/amnesia && chmod +x /usr/local/bin/amnesia
```

For those who - as me - doesn't like to type to many letters, may use much more friendly name: `ee`. `ee` is a sound I make when I can't remember command and parameters I want to use:

```
curl https://ofca.github.io/amnesia -o /usr/local/bin/ee && chmod +x /usr/local/bin/ee
```

## Scripts repository

Amnesia requires a URL from which it will download index and scripts.
Scripts repository must have `index` file listing all available scripts to run.

Example `index` file:

```
# Git.
id: log | description: See repo logs.

# Port.
id: usage | description: Check ports usage.
```

In the same directory as `index` you must have two scripts: `git_log.sh` and 
`port_usage.sh`:

**git_log.sh**:
```
#!/usr/bin/env bash

set -eo pipefail

action="$1"

if [ "$action" == "help" ]; then
  echo 'Git log help.'
  fi

git log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(auto)%d%C(reset)' --all
```

**port_usage.sh**:
```
#!/usr/bin/env bash

set -eo pipefail

action="$1"

if [ "$action" == "help" ]; then
  echo 'hello world'
  exit 0
  fi

lsof -nP -iTCP -sTCP:LISTEN
```

### Setting repository URL

Amnesia requires a URL from which it will download index and scripts. Execute
below to set scripts repository URL:

```
amnesia :url
```


