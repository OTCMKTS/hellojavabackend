# Ruby: Demo application for Datadog APM

A generic Ruby application with some common use scenarios.

For generating Datadog APM traces and profiles.

## Installation

Install [direnv](https://github.com/direnv/direnv) for applying local settings.

1. `cp .envrc.sample .envrc` and add your Datadog API key.
2. `direnv allow` to load the env var.
4. `docker-compose run --rm app bin/setup`

## Running the application

### To monitor performance of Docker containers with Datadog

```sh
docker run --rm --name dd-agent  -v /var/run/docker.sock:/var/run/docker.sock:ro -v /proc/:/host/proc/:ro -v /sys/fs/cgroup/:/host/sys/fs/cgroup:ro -e API_KEY=$DD_API_KEY datadog/docker-dd-agent:latest
```

### Starting the ap