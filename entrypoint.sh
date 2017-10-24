#!/bin/bash

envconsul -reload -consul  -upcase -prefix click-count-${ENVIRONMENT} catalina.sh run
