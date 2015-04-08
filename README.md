# Etcenv: Dump etcd keys into dotenv file or docker env file

[![Build Status](https://travis-ci.org/sorah/etcenv.svg)](https://travis-ci.org/sorah/etcenv)

## Installation

    $ gem install etcenv

## Simple Usage

### Create directory and keys on etcd

```
etcdctl mkdir /my-app
etcdctl set /my-app/AWESOME_SERVICE_CREDENTIAL xxxxxx
```

### Run `etcenv`

#### One-shot

This will output generated .env file to STDOUT.

```
$ etcenv /my-app
AWESOME_SERVICE_CREDENTIAL=xxxxxx
```

or

```
$ etcenv -o .env /my-app
$ cat .env
AWESOME_SERVICE_CREDENTIAL=xxxxxx
```

to save as file.

#### Continuously update

Etcenv also supports watching etcd server. In `--watch` mode, Etcenv updates dotenv file when value gets updated:

```
$ etcenv --watch -o .env /my-env
```

Also you can start it as daemon:

```
$ etcenv --watch --daemon /path/to/pidfile.pid -o .env /my-env
```

#### For docker

Use `--docker` flag to generate file for docker's `--env-file` option.

In docker mode, etcenv evaluates `${...}` expansion like dotenv do.

## Options

### etcd options

- `--etcd`: URL of etcd to connect to. Path in URL will be ignored.
- `--etcd-ca-file`: Path to CA certificate file (PEM) of etcd server.
- `--etcd-cert-file`: Path to client certificate file for etcd.
- `--etcd-key-file`: Path to private key file of client certificate file for etcd.

## Advanced usage

### Include other directory's variables

Set directory path to `.include`. Directories can be specified multiple, separated by comma.

```
etcdctl mkdir /common
etcdctl set /common/COMMON_SECRET xxx
etcdctl set /my-app/.include /common
```

Also, you can omit path of parent directory:

```
etcdctl mkdir /envs/common
etcdctl set /envs/common/COMMON_SECRET xxx

etcdctl mkdir /envs/my-app
etcdctl set /envs/my-app/.include common
```

- `.include` will be applied recursively (up to 10 times by default). If `.include` is looping, it'll be an error.
- For multiple `.include`, value for same key may be overwritten.
  - If `a` includes `b`,`c` and `b` includes `d`, result for `a` will be: `d`, `b`, `c`, then `a`.

## Development

After checking out the repo, run `scripts/setup` to install dependencies. Then, run `scripts/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

1. Fork it ( https://github.com/sorah/etcenv/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
