Run 'em in one line, removing all containers:

```sh
QGIS_TEST_VERSION=latest GITHUB_WORKSPACE=$PWD docker-compose -f .docker/docker-compose.yml run qgis /usr/src/.docker/run-docker-tests.sh; GITHUB_WORKSPACE=$PWD docker-compose -f .docker/docker-compose.yml rm -s -f
```

Be aware when having modelbaker lib as symbolic link, you will get ModelNotFound errors.
