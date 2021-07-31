# Rails 6: Demo application for Datadog APM

A generic Rails 6 web application with some common use scenarios.

For generating Datadog APM traces and profiles.

## Installation

Install [direnv](https://github.com/direnv/direnv) for applying local settings.

1. `cp .envrc.sample .envrc` and add your Datadog API key.
2. `direnv allow` to load the env var.
3. `docker-compose run --rm app bin/setup`

## Running the application

### To monitor performance of Docker containers with Datadog

```sh
docker run --rm --name dd-agent  -v /var/run/docker.sock:/var/run/docker.sock:ro -v /proc/:/host/proc/:ro -v /sys/fs/cgroup/:/host/sys/fs/cgroup:ro -e API_KEY=$DD_API_KEY datadog/docker-dd-agent:latest
```

### Starting the web server

```
# Run full application + load tester
# Binds to localhost:80
docker-compose up

# OR

# Run only the application (no load tester)
# Binds to localhost:80
docker-compose run --rm -p 80:80 app "bin/run <process>"
```

The `<process>` argument is optional, and will default to `DD_DEMO_ENV_PROCESS` if not provided. See [Processes](#processes) for more details.

#### Running a specific version of Ruby

By default it runs Ruby 2.7. You must reconfigure the application env variable `RUBY_VERSION`to use a different Ruby base image.

Setting the `RUBY_VERSION` variable to 3.2 on your .envrc file would use the `datadog/dd-apm-demo:rb-3.2` image.

If you haven't yet built the base image for this version, then you must:

1. Build an appropriate Ruby base image via `./integration/script/build-images -v 3.2`

Then rebuild the application environment with:

    ```
    # Delete old containers & volumes first
    docker-compose down -v

    # Rebuild `app` image
    docker-compose build --no-cache app
    ```

Finally start the application.

#### Running the local version of `ddtrace`

Useful for debugging `ddtrace` internals or testing changes.

Update the `app` --> `environment` section in `docker-compose.yml`:

```
version: '3.4'
services:
  ap