# Web stack debugging #1

Answer files for the ALU / Holberton **Web stack debugging #1** project.

| File | What it does |
| --- | --- |
| `0-nginx_likes_port_80` | Re-links the enabled Nginx site to the stock default site (which listens on port 80) and restarts Nginx. |
| `1-debugging_made_short` | 5-line version: same fix, then force-kills the Nginx master process so `service nginx status` reports *not running* while the worker processes keep answering on port 80. |

## Root cause

```
$ curl 0:80
curl: (7) Failed to connect to 0 port 80: Connection refused
$ ls -l /etc/nginx/sites-enabled/
-rw-r--r-- 1 root root ... default          <- a plain file, not a link
$ grep listen /etc/nginx/sites-enabled/default
	listen 8080 default_server;             <- wrong port
```

Nginx only reads sites from `/etc/nginx/sites-enabled/`. Normally `default` there is a
link to `/etc/nginx/sites-available/default`, which says `listen 80`. In the broken
machine it is a separate copy that says `listen 8080`, and Nginx is not running, so
nothing listens on port 80.

## Task 0

```bash
ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
service nginx restart
```

`ln -sf` replaces the broken copy with a link to the correct site, and the restart makes
Nginx load it. `listen 80` (no address) means every IPv4 address, shown as `0.0.0.0:80`.

## Task 1

```bash
ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
service nginx restart
pkill -9 -o nginx
```

Nginx runs as one **master** process plus several **worker** processes. The workers hold
the open port 80 and answer requests. `service nginx status` only checks whether the
master (the process ID in `/run/nginx.pid`) is alive.

- `pkill -o nginx` picks the **o**ldest Nginx process, which is the master.
- `-9` (SIGKILL) kills it instantly, so it cannot tell the workers to shut down.
  The workers keep running and keep serving port 80, but the status check finds no master
  and prints `nginx is not running`.
- A plain `pkill -o nginx` (SIGTERM) does **not** work: the master shuts down gracefully
  and takes the workers with it, so port 80 stops answering.

This is a trick for the exercise, not something to do on a real server: without the
master, Nginx can no longer reload its config or replace a crashed worker.

## Tests

Run in a Docker reproduction of the broken machine (Ubuntu 20.04, Nginx 1.18, enabled site
copied with `listen 8080`, Nginx stopped), because the original sandbox is only available
from the intranet. The reproduction has no IPv6, so its `[::]` listen lines were removed;
real servers keep them.

| Check | Task 0 | Task 1 |
| --- | --- | --- |
| `curl -sI 0:80` before | connection refused | connection refused |
| `curl -sI 0:80` after | `HTTP/1.1 200 OK` | `HTTP/1.1 200 OK` |
| `ss -ltn` | `0.0.0.0:80` | `0.0.0.0:80` |
| `service nginx status` | `nginx is running` | `nginx is not running` |

Task 1 was also run on a machine where task 0 had already been applied: same result.
`1-debugging_made_short` has 5 lines, ends with a newline, and contains no `;`, `&&`,
`wget`, or reference to the task 0 script.
