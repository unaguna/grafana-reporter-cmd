# Grafana Reporter Command

This project is wrapper of [Grafana reporter](https://github.com/IzakMarais/reporter).
It is intended to make complex configuration more intuitive by specializing in using the reporter in the docker image as a CUI command.

## Requirement for use

- Docker must be available. The following commands can be used to check.

    ```shell
    docker --version
    docker ps
    docker-compose --version
    ```

- [Renderer plugin](https://grafana.com/grafana/plugins/grafana-image-renderer/) must be installed in the target grafana server.
  

## Set Up

1. Change the value of `GRAFANA_HOST` in [docker-compose.yml](./docker-compose.yml) to your Grafana server's information.
2. Make a file `./reporter/local/grafana.apikey`. Write an api key of your Grafana in this file. For example:
    ```plane
    eyJrIjoiQlBIM1ZLTEs3MXdaQ09HRXRsbTQ1RTZzZ2gwM1FKNGUiLCWPIjoiZ3JhZmFuYS1yZXBvc894257d35459aoxfQ==
    ```


## Usage

1. Start the docker container

    ```shell
    docker-compose up -d
    ```

2. Run the wrapper script, `gpdf`, in the container. For example:

    ```shell
    docker-compose exec reporter gpdf --template landscape <dashboard_uid>
    ```

    Specify each argument as follows:

    - **--template <template_name>**: Name of the template to be used. The contents of `./reporter/templates/` can be used, and `landscape` and `portrait` are available by default.
    - **<dashboard_uid>**: UID of the dashboards you want to convert to PDF. For example: `OX1JIm97j`.

    The result PDF will be output under `./reporter/pdf-dest/`.
