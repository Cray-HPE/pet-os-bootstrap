#!/bin/bash

if [ ! -f /usr/bin/check-default-route.sh ]; then
  echo "Setting up default route cronjob"

  echo "#!/bin/bash

  echo \"Checking that default route is set correctly\"
  output=\$(ip r | grep -q default)
  rc=\$?
  if [ "\$rc" -ne 0 ]; then
    echo "Adding default route"
    ip route add default via 10.248.0.1
  fi" > /usr/bin/check-default-route.sh

  chmod 755 /usr/bin/check-default-route.sh
  /usr/bin/check-default-route.sh
  echo "* * * * * root /usr/bin/check-default-route.sh" > /etc/cron.d/check-default-route
  systemctl restart cron
fi
