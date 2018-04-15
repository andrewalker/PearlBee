# PearlBee [![Build Status](https://travis-ci.org/andrewalker/PearlBee.svg?branch=master)](https://travis-ci.org/andrewalker/PearlBee)

An open source blogging platform written in Perl. [pearlbee.org](http://pearlbee.org)

Don't run tests against a production database! Make sure dbic.yaml has
different values for `TESTING_DATABASE` and `DEFAULT_DATABASE`.

## Setup

You can try it for yourself!

On Linux will need libxml2 installed, while Mac OSX already provides it.

### On Ubuntu or Debian based Linux

```shell
$ sudo apt-get install libxml2-dev
$ git clone git@github.com:Perl-Evozon/PearlBee.git
$ cd PearlBee
$ ./bin/bootstrap
```

### On Fedora or RedHat based Linux

```shell
$ sudo yum install libxml2-devel
$ git clone git@github.com:Perl-Evozon/PearlBee.git
$ cd PearlBee
$ ./bin/bootstrap
```

### On Mac OSX

```shell
$ git clone git@github.com:Perl-Evozon/PearlBee.git
$ cd PearlBee
$ ./bin/bootstrap
```

## Running

```shell
./bin/launch-devel
```

The initial user is `admin` and the password is `password`.

## PearlBee in news

[Is PearlBee Perl's next great blogging platform?](http://perltricks.com/article/69/2014/2/17/Is-PearlBee-Perl-s-next-great-blogging-platform-) - Perl Tricks

Thank you for using PearlBee!
