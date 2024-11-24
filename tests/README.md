## Test *Gantry* Docker service updater

[![Coverage](https://img.shields.io/codecov/c/github/shizunge/gantry.svg?token=47MWUJOH4Q&label=Coverage&logo=Codecov)](https://codecov.io/gh/shizunge/gantry)
[![CodeFactor Grade](https://img.shields.io/codefactor/grade/github/shizunge/gantry?label=CodeFactor&logo=CodeFactor)](https://www.codefactor.io/repository/github/shizunge/gantry)

Majority of the configuration options are covered by end-to-end tests. The tests are utilizing [shellspec](https://github.com/shellspec/shellspec) framework. A quick installation of `shellspec` can be done by `curl -fsSL https://git.io/shellspec | sh`. See their website for more installation options.

The tests will create a local registry, testing images, and services. Testing images are pushed to the local registry, therefore no external registry is needed. Then the tests will run *Gantry* to update these services.

Use the following commands to run all the tests locally. The tests run *Gantry* scripts on the host, but it should not affect any running docker swarm services on the host.
```
bash shellspec
```

To run only selected tests
```
# Filter tests by name.
bash shellspec --example <example_name>
# Run tests within a file.
bash shellspec --pattern tests/<file_name>
# Or combination of both
bash shellspec --pattern tests/<file_name> --example <example_within_the_file>
```

To run multiple tests in parallel
```
bash shellspec --jobs 50
```

To generate coverage (require [kcov](https://github.com/SimonKagstrom/kcov) installed):
```
bash shellspec --kcov --tag coverage:true
```

If you want to test a container image of *Gantry*, you need to specify the image of *Gantry* via the environment variable `GANTRY_TEST_CONTAINER_REPO_TAG`.
```
export GANTRY_TEST_CONTAINER_REPO_TAG=<gantry image>:<tag>
bash shellspec --tag "container_test:true" "coverage:true"
```

> NOTE: Negative tests will hang when testing a *Gantry* container, which may be due to a bug in shellspec. So when testing *Gantry* images, we should run only tests with tag `container_test:true`.

