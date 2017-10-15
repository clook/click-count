#!/bin/sh

curl '%CONCOURSE_URL%/api/v1/cli?arch=amd64&platform=linux' > /usr/local/bin/fly
chmod +x /usr/local/bin/fly

fly login -u concourse -p concourse -c %CONCOURSE_URL% -t xebia-test

cd /pipelines
echo Adding hello-world
fly -t xebia-test set-pipeline -n -p hello-world -c hello.yml
echo Adding click-count
fly -t xebia-test set-pipeline -n -p click-count -c click-count.yml
