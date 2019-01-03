# PearlBee [![Build Status](https://travis-ci.org/andrewalker/PearlBee.svg?branch=master)](https://travis-ci.org/andrewalker/PearlBee)

An open source blogging platform written in Perl.

Don't run tests against a production database! Make sure dbic.yaml has
different values for `TESTING_DATABASE` and `DEFAULT_DATABASE`.

## Setup

Requires PostgreSQL server.

Example configuration:

```shell
sudo su - postgres -c "createuser $USER"
sudo su - postgres -c "createdb -O$USER pearlbee"
sudo su - postgres -c "createdb -O$USER pearlbee_testing" # for running the tests
```

The values above are the default in the configuration (dbic.yaml and
sqitch.conf), but you can always tweak for your own needs.

When running on Linux, you might need to install libxml2-dev or libxml2-devel,
depending on your distro.

To install all the required Perl modules:

```shell
./bin/bootstrap
```

## Running

```shell
./bin/launch-devel
```

The initial user created by the bootstrap script is `admin` and the password is
`password`.
