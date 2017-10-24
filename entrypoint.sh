#!/bin/bash

envconsul -consul ${HOST_CONSUL} -upcase -prefix click-count-${ENVIRONMENT} catalina.sh run
