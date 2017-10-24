#!/bin/bash

envconsul -consul  -upcase -prefix click-count-${ENVIRONMENT} catalina.sh run
