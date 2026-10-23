# HTTPS SSL

Answer files for the ALU / Holberton **HTTPS SSL** project, for the domain `ema-love.tech`.

> **Submission note:** the assignment expects these files in the repository
> `alu-webstack`, directory `https_ssl`. This copy lives in `alu-intranet-assignment`
> as a working copy; copy the folder into `alu-webstack` before submitting.

| File | What it is |
| --- | --- |
| `0-world_wide_web` | Bash script: `./0-world_wide_web DOMAIN [SUBDOMAIN]` prints the record type and destination of `www`, `lb-01`, `web-01`, `web-02` (in that order), or only of `SUBDOMAIN`. Uses `dig`, `awk` and a function. |
| `1-haproxy_ssl_termination` | HAProxy config (`/etc/haproxy/haproxy.cfg` on lb-01): HTTP on port 80, HTTPS on port 443 with the Let's Encrypt certificate for `www.ema-love.tech`, decrypted traffic sent round robin to web-01 and web-02. |
| `2-redirect_http_to_https` | Same config as task 1, except port 80 now answers every request with `301 Moved Permanently` to the `https://` version of the same URL. |

The two config files differ by exactly one line (the `frontend http_front` rule).

## Step 1: DNS records (at your DNS provider, for `ema-love.tech`)

| Type | Name (host) | Value |
| --- | --- | --- |
| A | `www` | `44.201.241.113` (lb-01) |
| A | `lb-01` | `44.201.241.113` |
| A | `web-01` | `184.73.0.98` |
| A | `web-02` | `54.174.254.122` |

Check from your own computer once DNS has updated:

```bash
./0-world_wide_web ema-love.tech
# The subdomain www is a A record and points to 44.201.241.113
# The subdomain lb-01 is a A record and points to 44.201.241.113
# The subdomain web-01 is a A record and points to 184.73.0.98
# The subdomain web-02 is a A record and points to 54.174.254.122
./0-world_wide_web ema-love.tech web-02
# The subdomain web-02 is a A record and points to 54.174.254.122
```

## Step 2: backend servers

Both config files already point at `6833-web-01` (`184.73.0.98`) and
`6833-web-02` (`54.174.254.122`), the same backends as `load_balancer/1-install_load_balancer`.

## Step 3: get the certificate on lb-01 (needs `www` already pointing to lb-01)

```bash
sudo apt-get update && sudo apt-get install -y certbot
sudo service haproxy stop                     # certbot needs port 80 for a moment
sudo certbot certonly --standalone -d www.ema-love.tech
sudo mkdir -p /etc/haproxy/certs
sudo sh -c 'cat /etc/letsencrypt/live/www.ema-love.tech/fullchain.pem \
               /etc/letsencrypt/live/www.ema-love.tech/privkey.pem \
               > /etc/haproxy/certs/www.ema-love.tech.pem'
sudo chmod 600 /etc/haproxy/certs/www.ema-love.tech.pem
```

HAProxy wants the certificate and its private key in **one** file, which is why the two
Let's Encrypt files are joined. The certificate lasts 90 days; to renew, repeat the
stop / `certbot renew` / join / start steps.

## Step 4: install the config on lb-01

```bash
sudo cp 1-haproxy_ssl_termination /etc/haproxy/haproxy.cfg     # task 1
sudo haproxy -c -f /etc/haproxy/haproxy.cfg && sudo service haproxy restart
curl -sI https://www.ema-love.tech          # HTTP/1.1 200 OK + X-Served-By
curl https://www.ema-love.tech              # Holberton School

sudo cp 2-redirect_http_to_https /etc/haproxy/haproxy.cfg      # task 2
sudo haproxy -c -f /etc/haproxy/haproxy.cfg && sudo service haproxy restart
curl -sIL http://www.ema-love.tech          # 301 + Location: https://www.ema-love.tech/, then 200
```

Port 443 must be open in any firewall in front of lb-01 (`sudo ufw allow 443/tcp` if ufw is on).

## Configuration choices

- **SSL termination**: HAProxy decrypts HTTPS on lb-01 and talks plain HTTP to the web
  servers, so only lb-01 needs a certificate and the web servers stay unchanged.
- **`alpn http/1.1`**: HAProxy 2.x would otherwise offer HTTP/2, where headers are always
  lowercase; this keeps responses as `HTTP/1.1 200 OK` with `X-Served-By`, as in the project examples.
- **`h1-case-adjust`**: keeps `X-Served-By` and `Location` capitalized on HTTP/1.1.
- **`option forwardfor` / `X-Forwarded-Proto`**: tell the web servers the visitor's real IP
  and whether they came in over HTTP or HTTPS.
- **`redirect scheme https code 301 unless { ssl_fc }`**: anything that did not arrive over
  SSL gets a permanent redirect to the same host, path and query string on `https://`.
