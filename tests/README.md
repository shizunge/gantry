## Test *Gantry* Docker service updater

[![codecov](https://codecov.io/gh/shizunge/gantry/graph/badge.svg?token=47MWUJOH4Q)](https://codecov.io/gh/shizunge/gantry)

Majority of the configuration options are covered by end-to-end tests. The tests are utilizing [shellspec](https://github.com/shellspec/shellspec) framework. A quick installation of `shellspec` can be done by `curl -fsSL https://git.io/shellspec | sh`. See their website for more installation options.

The tests will create a local registry, testing images, and services. Testing images are pushed to the local registry, therefore no external registry is needed. Then the tests will run *Gantry* to update these services.

To test *Gantry* scripts, and run all the tests locally:
```
bash shellspec
```

To run only selected tests
```
# Filter tests by name.
bash shellspec --example <example_name>
# Run tests within a file.
bash shellspec --pattern tests/<file_name>
```

To generate coverage (need [kcov](https://github.com/SimonKagstrom/kcov) installed):
```
bash shellspec --kcov
```

If you want to test a container image of *Gantry*, you need to specify the image of *Gantry* via the environment variable `GANTRY_TEST_CONTAINER_REPO_TAG`.
```
export GANTRY_TEST_CONTAINER_REPO_TAG=<gantry image>:<tag>
bash shellspec
```
