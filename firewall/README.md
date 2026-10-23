# Firewall

Answer files for the ALU / Holberton **Firewall** project (UFW on `web-01`).

> **Submission note:** the assignment expects these files in the repository
> `alu-system_engineering-devops`, directory `firewall`. This copy lives in
> `alu-intranet-assignment` as a working copy; copy the folder over before submitting.

| File | What it is |
| --- | --- |
| `0-block_all_incoming_traffic_but` | The UFW commands to run on web-01: block all incoming traffic except SSH (22), HTTP (80) and HTTPS (443). |
| `100-port_forwarding` | A copy of `/etc/ufw/before.rules` (from Ubuntu 24.04, UFW 0.36.2) with one `*nat` block added so TCP port 8080 is redirected to port 80. Everything else is the stock file. |

## Task 0: on web-01

Run the commands in `0-block_all_incoming_traffic_but` one by one. **Port 22 is allowed
before `ufw enable`**, so your SSH session keeps working. Keep that session open and,
from a second terminal, check you can still log in before closing it.

Expected `sudo ufw status verbose`:

```
Status: active
Default: deny (incoming), allow (outgoing), disabled (routed)
To                         Action      From
22/tcp                     ALLOW IN    Anywhere
80/tcp                     ALLOW IN    Anywhere
443/tcp                    ALLOW IN    Anywhere
22/tcp (v6)                ALLOW IN    Anywhere (v6)
...
```

If your server's UFW is an older version, compare its `/etc/ufw/before.rules` with this
copy before replacing it (`diff /etc/ufw/before.rules 100-port_forwarding`): the only
difference should be the `*nat` block.

## Task 1 (advanced): on web-01, after task 0

```bash
sudo cp /etc/ufw/before.rules /etc/ufw/before.rules.bak   # backup
diff /etc/ufw/before.rules 100-port_forwarding            # should only show the *nat block
sudo cp 100-port_forwarding /etc/ufw/before.rules
sudo ufw reload
sudo iptables -t nat -L PREROUTING -n                     # REDIRECT tcp dpt:8080 redir ports 80
```

Test **from another machine** (your computer or lb-01), because the rule only applies
to traffic arriving from the network, not to `curl localhost:8080` on web-01 itself:

```bash
curl -sI 184.73.0.98:8080     # same response as port 80, X-Served-By: 6833-web-01
```

The rule is stored in UFW's config file and UFW is enabled on startup, so it comes back
after a reboot (`sudo reboot`, then repeat the curl).

## How it works

- **`default deny incoming`** closes every door; **`allow 22/80/443`** opens only SSH,
  web and secure web. Outgoing traffic (updates, DNS) stays allowed.
- **`*nat` / `PREROUTING` / `REDIRECT --to-port 80`**: before the firewall decides
  anything, packets arriving for port 8080 are relabelled as port 80. They then pass the
  existing `80/tcp` allow rule and reach Nginx, so port 8080 does **not** need its own
  allow rule.
- **No `ip_forward` change**: `REDIRECT` sends traffic to a port on the same machine.
  IP forwarding (`net/ipv4/ip_forward=1`) is only needed to pass traffic on to a
  *different* machine, so it is left off.
