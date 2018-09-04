#!/bin/bash -e

echo Uninstalling Dynatrace Managed
/opt/dynatrace-managed/uninstall-dynatrace.sh --unregister
echo Uninstalling finished
