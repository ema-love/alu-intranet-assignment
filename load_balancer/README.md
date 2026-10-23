# Load balancer

Scripts for the ALU / Holberton **Load balancer** project.

> **Submission note:** the assignment expects these files in the repository
> `alu-system_engineering-devops`, directory `load_balancer`. This copy lives in
> `alu-intranet-assignment` as a working copy; copy the folder into the required
> repository before submitting, or the checker will not find it.

| File | Run on | What it does |
| --- | --- | --- |
| `0-custom_http_response_header` | `web-01` **and** `web-02` | Installs and configures Nginx (same setup as `web_server/4-not_found_page_404`) and adds the response header `X-Served-By: <hostname of that server>`. |
| `1-install_load_balancer` | `lb-01` | Installs HAProxy, sends HTTP traffic to `web-01` and `web-02` in turn (`roundrobin`), checks the config, then restarts with the init script. |

## Servers

| Name | IP |
| --- | --- |
| `6833-web-01` | `184.73.0.98` |
| `6833-web-02` | `54.174.254.122` |
| `6833-lb-01` | `44.201.241.113` |

`1-install_load_balancer` has these backend values filled in at the top.

## Run order

```bash
# on web-01 and on web-02
sudo ./0-custom_http_response_header
curl -sI localhost | grep X-Served-By      # shows that server's own hostname

# on lb-01
sudo ./1-install_load_balancer
curl -sI localhost | grep X-Served-By      # run it a few times: web-01, web-02, web-01, ...
```

From your own computer: `curl -sI 44.201.241.113` repeated should alternate between the two hostnames.

## Configuration choices

- **`add_header X-Served-By $hostname always;`**: `$hostname` is filled in by Nginx on
  the machine it runs on, so one script works unchanged on both web servers. `always`
  adds the header to error pages and redirects too.
- **`balance roundrobin`**: each new request goes to the next server in the list.
- **`check`** on each server: HAProxy stops sending traffic to a web server that is down.
- **`h1-case-adjust`**: HAProxy 2.x lowercases header names (`x-served-by`); this keeps
  the original `X-Served-By` spelling for anything that matches it exactly.
- **`ENABLED=1` in `/etc/default/haproxy`** and `service haproxy restart`: the classic
  Ubuntu init-script setup, without `systemctl`.
- **`haproxy -c -f ... && service haproxy restart`**: HAProxy only restarts if the new
  config is valid, so a typo cannot take the load balancer down.
