#!/bin/bash
# Launch the E.2 treatment arm detached. Logs to ~/e2_treatment.log.
cd "$HOME" || exit 1
setsid bash -c '. ~/.wireclaw-tg-env && ~/phase31-venv/bin/python -u ~/phase_4_4_0e_ab_driver.py --arm treatment > ~/e2_treatment.log 2>&1; echo DRIVER-EXIT=0 >> ~/e2_treatment.log' </dev/null >/dev/null 2>&1 &
echo "treatment-launched pid=$!"
