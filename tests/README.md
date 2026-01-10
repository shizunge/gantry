## Test *Gantry* Docker service updater

[![Coverage](https://img.shields.io/codecov/c/github/shizunge/gantry.svg?token=47MWUJOH4Q&label=Coverage&logo=Codecov)](https://codecov.io/gh/shizunge/gantry)
[![CodeFactor Grade](https://img.shields.io/codefactor/grade/github/shizunge/gantry?label=CodeFactor&logo=CodeFactor)](https://www.codefactor.io/repository/github/shizunge/gantry)

Majority of the configuration options are covered by end-to-end tests. The tests are utilizing [shellspec](https://github.com/shellspec/shellspec) framework. A quick installation of `shellspec` can be done by `curl -fsSL https://git.io/shellspec | sh`. See their website for more installation options.

The tests will create a local registry, testing images, and services. Testing images are pushed to the local registry, therefore no external registry is needed. Then the tests will run *Gantry* to update these services.

Use the following commands to run all the tests locally. The tests run *Gantry* scripts on the host, but it should not affect any running docker swarm services on the host.
```
shellspec -s bash
```

To run only selected tests
```
# Filter tests by name.
shellspec -s bash --example <example_name>
# Run tests within a file.
shellspec -s bash --pattern tests/<file_name>
# Or combination of both
shellspec -s bash --pattern tests/<file_name> --example <example_within_the_file>
```

To run multiple tests in parallel
```
shellspec -s bash --jobs 50
```

To generate coverage (require [kcov](https://github.com/SimonKagstrom/kcov) installed):
```
shellspec -s bash --kcov
```

The above commands test *Gantry* as a script running on the host directly. We also want to test *Gantry* running inside a container in case the environments are different between the host and the container.

To test *Gantry* running inside a container, set the environment variable `GANTRY_TEST_CONTAINER` to `true`. The testing framework will build a local image of *Gantry*, then start a service of that image to run the test.

```
export GANTRY_TEST_CONTAINER=true
shellspec -s bash --jobs 50
```

If you want to test a specific image of *Gantry*, you need to set the image of *Gantry* explicitly via the environment variable `GANTRY_TEST_CONTAINER_REPO_TAG`.

```
export GANTRY_TEST_CONTAINER_REPO_TAG=<gantry image>:<tag>
shellspec -s bash --jobs 50
```
