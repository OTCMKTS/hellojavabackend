# Rack: Demo application for Datadog APM

A generic Rack web application with some common use scenarios.

For generating Datadog APM traces and profiles.

## Installation

Install [direnv](https://github.com/direnv/direnv) for applying local settings.

1. `cp .envrc.sample .envrc` and add your Datadog API key.
2. `direnv allow` to load the env var.
4. `docker-compose run --rm app bin/setup`

## Running the application

### To monitor performance of Docker containers with Datado