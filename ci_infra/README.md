# Xebia click-count CI/CD

## How to use it?
### Prerequesties
You must have:
* at least 10-12 GB available on your disk
* Vagrant installed on your machine and bash shell
* access to HTTP/HTTPS Internet (Docker Hub, Vagrant, Debian APT repo, Python PIP packages...)
* access to DNS services (208.67.222.222 DNS)
* access Xebia Redis external hosts (TCP/6379)
* a way to configure your DNS resolver configuration

### Usage
* clone the project and bootstrap CI infra:
```
git clone https://github.com/clook/click-count.git
cd click-count/ci_infra
./bootstrap_infra.sh
```
* add the CI infra DNS resolver to your nameserver lists (default: 192.168.33.10)
* fill the `click-count.ci.conf` file with Xebia Redis external hosts IPs
* configure the CI/CD pipeline and trigger a first build:
```
./launch_ci.sh
```

You should be able to track the progress by logging on http://concourse.xebia-test with team main:
* login: concourse
* password: concourse

When deploy-staging is over:
* you should be able to log and test on http://staging.click-count.xebia-test
* you may trigger manually the deploy-prod build (click on it and click on the "+" of top right corner)

When deploy-prod is over, you should be able to log and check on http://click-count.xebia-test

Concourse tracks master branch (every minute) so that every push to this branch trigger a new build.

## Tech and design
WIP, see design.txt as now.
