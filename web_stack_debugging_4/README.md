# Web stack debugging #4

Puppet answer files for the ALU / Holberton **Web stack debugging #4** project.

| File | What it fixes |
| --- | --- |
| `0-the_sky_is_the_limit_not.pp` | Nginx fails requests under load: raises the open-file limit it is started with from 15 to 4096 and restarts Nginx (only when changed). |
| `1-user_limit.pp` | The `holberton` user gets `Too many open files`: raises its limits in `/etc/security/limits.conf` from 4/5 to the usual 1024 (soft) / 4096 (hard). |

## Task 0: why Nginx failed requests

Evidence gathered before changing anything:

| Check | Finding |
| --- | --- |
| `ab -c 100 -n 2000 localhost/` | 60–77 failed requests per run in testing (943 in the assignment example) |
| `/var/log/nginx/error.log` | `open() "/var/www/html/index.nginx-debian.html" failed (24: Too many open files)` once per failed request, plus `accept4() failed (24: Too many open files)` |
| `grep "Max open files" /proc/<nginx pid>/limits` | **15** for the master and every worker |
| Origin | `ULIMIT="-n 15"` in `/etc/default/nginx`, applied by `ulimit $ULIMIT` in `/etc/init.d/nginx` |
| `nginx.conf` | `worker_connections 768` |
| `/proc/sys/fs/file-max` | about 1.6 million: the system-wide limit is not the problem |

A worker needs about two open files per connection (the client socket and the page it is
sending). With only 15 allowed, it cannot even accept a handful of the 100 simultaneous
connections, so requests fail.

**Fix:** set `ULIMIT="-n 4096"` (the example value Ubuntu suggests in that file). That covers 768
connections × 2 files with room to spare. Then restart Nginx: the limit is only applied when the
master process starts, so a `reload` would not be enough. The restart is triggered only when the
file actually changed (`notify` + `refreshonly`).

## Task 1: why holberton gets "Too many open files"

```
$ su - holberton -c 'ulimit -Sn; ulimit -Hn'
/etc/profile.d/01-locale-fix.sh: cannot make pipe for command substitution: Too many open files
4
5
$ grep holberton /etc/security/limits.conf
holberton hard nofile 5
holberton soft nofile 4
```

`pam_limits` (enabled in `/etc/pam.d/su` and `/etc/pam.d/login`) applies these lines at every
login. Every process starts with 3 files open (input, output, error), so a limit of 4 leaves room
for almost nothing: the login scripts and `head /etc/passwd` fail.

**Fix:** change those two lines to `soft 1024` and `hard 4096`.

- 1024 is the soft limit every other login gets on this system (`su - root` shows 1024), so
  `holberton` behaves like a normal user.
- 4096 lets the user raise their own limit for a heavier job, without being unlimited.
- Each `exec` runs only while the matching limit is below 1000 (`onlyif`), so running Puppet
  again changes nothing. No other user's limits are touched.

The change applies to **new** login sessions: log out and back in (or `su - holberton`).

## Tests

Run in a Docker reproduction, because the original sandbox is only available from the intranet.
The reproduction is Ubuntu 20.04 with Nginx 1.18, ApacheBench 2.3 and Puppet 5.5.10. It was given
the documented sandbox faults: `ULIMIT="-n 15"` in `/etc/default/nginx`, and `holberton` soft
4 / hard 5 `nofile` in `limits.conf`. The machine has 4 CPUs (4 Nginx workers), which is why the
baseline failure count differs from the assignment's 943.

| Check | Task 0 | Task 1 |
| --- | --- | --- |
| `puppet parser validate` | OK | OK |
| `puppet-lint` 2.4.2 | no warnings | no warnings |
| Before | 77 failed / 2000 (60 in a second container) | `soft=4 hard=5`, `Too many open files` on login |
| 1st `puppet apply` | exit 2: limit changed, Nginx restarted | exit 2: both lines changed |
| After | 0 failed / 2000 in 3 of 3 runs; all Nginx processes at 4096; error log empty | new `su -` and `runuser -l` sessions: `soft=1024 hard=4096`; `head /etc/passwd` prints 10 lines, no errors |
| 2nd `puppet apply` | exit 0, Nginx not restarted | exit 0, nothing changed |
| Persistence | after a later manual Nginx stop/start: still 4096, 0 failed | root login unchanged (`1024`/`20000` before and after) |
