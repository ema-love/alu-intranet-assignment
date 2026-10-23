# Web stack debugging #2

Answer files for the ALU / Holberton **Web stack debugging #2** project.

| File | What it does |
| --- | --- |
| `0-iamsomeoneelse` | `sudo -u "$1" whoami`: runs `whoami` as the user given as the first argument. |
| `1-run_nginx_as_nginx` | Reconfigures Nginx so its master and worker processes run as the `nginx` user and listen on port 8080 on all IPv4 addresses. |
| `100-fix_in_7_lines_or_less` | The same result in 7 lines, without `;`, `&&` or `wget`. |

## Task 0

```bash
$ ./0-iamsomeoneelse www-data
www-data
$ ./0-iamsomeoneelse root
root
```

`sudo -u USER command` runs one command as another user and then returns to your own
shell, so your shell's user never changes.

## Root cause (task 1)

What the broken machine looked like before the fix:

```
root      nginx: master process /usr/sbin/nginx      <- master runs as root
www-data   \_ nginx: worker process                  <- workers as www-data
LISTEN 0.0.0.0:80    nginx                           <- wrong port
LISTEN 0.0.0.0:8080  apache2                         <- 8080 already taken
-rw------- root root /etc/nginx/nginx.conf           <- nginx user cannot read it
```

Starting Nginx as the `nginx` user straight away fails, for several reasons at once:

| Problem | Effect |
| --- | --- |
| `nginx.conf` is readable by root only | `open() "/etc/nginx/nginx.conf" failed (13: Permission denied)` |
| `/var/log/nginx` files belong to `www-data` | cannot write `error.log` |
| `/var/lib/nginx/*` temp folders belong to `www-data` | cannot store request bodies |
| PID file is in `/run`, writable by root only | cannot write `/run/nginx.pid` |
| Apache listens on port 8080 | `bind() to 0.0.0.0:8080 failed (98: Address already in use)` |
| The site says `listen 80` | wrong port |

## Task 1: the fix, step by step

1. `service nginx stop` and `service apache2 stop`: stop the root Nginx, and free port
   8080 without removing Apache.
2. `chmod 644 /etc/nginx/nginx.conf`: everyone may read the config (still only root may change it).
3. `user nginx;` in `nginx.conf`: names the intended user.
4. `listen 8080` in the default site: `listen 8080` with no address means every IPv4
   address (`0.0.0.0:8080`).
5. `chown` the logs, the temp folders and a pre-created `/run/nginx.pid` to `nginx`.
6. `su nginx -s /bin/bash -c 'nginx'`: start Nginx **as** `nginx`. The `nginx` account has no
   login shell, so `-s /bin/bash` supplies one just for this command.

Why start it as `nginx` instead of `service nginx start`? The service starts the master
as root, and only the workers switch user. The assignment wants the **master** to run as
`nginx` too, so Nginx has to be launched by that user. Port 8080 is above 1024, so a
normal user is allowed to open it.

Nginx prints `the "user" directive makes sense only if the master process runs with
super-user privileges, ignored`. That warning is expected: a non-root master cannot switch
users, so everything simply runs as `nginx`.

## Task 2: same fix in 7 lines

```bash
service apache2 stop
pkill nginx
sed -i -e 's/listen \(\[::\]:\)\?80 default/listen \18080 default/' -e 's#/run/nginx.pid#/var/lib/nginx/nginx.pid#' /etc/nginx/nginx.conf /etc/nginx/sites-available/default
chown -R nginx:nginx /etc/nginx/nginx.conf /var/log/nginx /var/lib/nginx
su nginx -s /bin/bash -c nginx
```

Differences from task 1, to fit in 7 lines with no `;`:

- The PID file moves to `/var/lib/nginx/nginx.pid`, a folder that is already being given
  to `nginx`, instead of pre-creating one in `/run`.
- `nginx.conf` is made readable by giving `nginx` ownership of it rather than `chmod 644`.
  It works, but it also lets the `nginx` user edit the file, which task 1 avoids.
- The two `sed` edits use separate `-e` options instead of a `;`.
- `service apache2 stop` waits until Apache has fully released port 8080. An earlier
  version used `pkill apache2`, which returns before the port is free and produced
  `bind() ... Address already in use` in 4 of 5 test runs (Nginx then succeeded only by
  retrying).

## Tests

Task 0 ran on an Ubuntu 24.04 machine: `www-data`, `root` and `nobody` each printed their
own name, and the shell stayed `root`.

Tasks 1 and 2 ran in a Docker reproduction of the broken sandbox, because the original is
only available from the intranet. The reproduction is Ubuntu 20.04 with Nginx 1.18 and
Apache 2. Nginx runs as root on port 80, Apache is on 8080, `nginx.conf` is mode 600, and an
`nginx` user exists. The reproduction has no IPv6, so its `[::]` listen lines were removed.
The task 2 `sed` was separately checked on the stock lines and rewrites both
`listen 80 default_server` and `listen [::]:80 default_server` to 8080.

| Check | Task 1 (3 fresh runs) | Task 2 (5 fresh runs) |
| --- | --- | --- |
| `ps` master + workers | all `nginx` | all `nginx` |
| `ss -ltn` | `0.0.0.0:8080` only | `0.0.0.0:8080` only |
| `curl` on `0`, `127.0.0.1`, container IP, port 8080 | `200` | `200` |
| Apache | stopped, package still installed | stopped |
| Errors | none | none |
