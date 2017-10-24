#!/bin/bash

envconsul -consul ${CONSUL_HOST} -upcase -prefix click-count-${ENVIRONMENT} catalina.sh run
