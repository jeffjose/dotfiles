# systemd

|                            | initd                             | systemd                                     |
| -------------------------- | --------------------------------- | ------------------------------------------- | ----------------------- |
| List of all services       | `chkconfig --list`                | `systemctl list-units --type service --all` |
| Runlevels/targets          | `cat /etc/inittab` and `runlevel` | `systemctl list-units --type target`        |
| All scripts                | `/etc/init.d`                     | `/usr/lib/systemd/system`                   |
| Enabled/diabled scripts    | `/etc/rc${level}.d/`              | `/etc/systemd/system`                       |
| Check status               | `service httpd status`            | `systemctl status httpd`                    |
| Enable a service           | `chkconfig --level 35 httpd on`   | `systemctl enable httpd.service`            |
| Find the curr level/target | `cat /etc/inittab                 | tail`                                       | `systemctl get-default` |
| Set runlevel/target        | ?                                 | `systemctl set-default multi-user.target`   |
