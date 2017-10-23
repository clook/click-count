#!/bin/sh

TRY_MAX=60

try=0


while ! curl -f '%CONCOURSE_URL%/api/v1/cli?arch=amd64&platform=linux' > /usr/local/bin/fly
do
	if [[ "$try" -gt "$TRY_MAX" ]]; then
		echo "Can't download fly"
		exit 1
	fi
	try=$((try + 1))
	sleep 1
done

chmod +x /usr/local/bin/fly

fly login -u concourse -p concourse -c %CONCOURSE_URL% -t xebia-test

cd /pipelines
echo Adding click-count
fly -t xebia-test set-pipeline -n -p click-count -c click-count.yml --load-vars-from credentials.yml
fly -t xebia-test unpause-pipeline --pipeline click-count
fly -t xebia-test trigger-job --job click-count/build-image
