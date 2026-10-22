# Web server

Scripts and files for the ALU / Holberton **Web server** project.
All Bash scripts target Ubuntu, start with `#!/usr/bin/env bash`, pass `shellcheck`,
and restart Nginx with `service nginx restart` (never `systemctl`).

| File | What it does |
| --- | --- |
| `0-transfer_file` | Copies a file to `~/` of a remote user with `scp`, using the given SSH key and no strict host-key checking. Prints a usage message if fewer than 4 arguments are given. |
| `1-install_nginx_web_server` | Installs Nginx, makes it listen on port 80 and serve `Holberton School` at `/`. |
| `2-setup_a_domain_name` | **Not created yet:** needs your real root domain (see below). |
| `3-redirection` | Fresh-machine setup: everything from task 1 plus `/redirect_me` → `301 Moved Permanently` to `https://www.youtube.com/watch?v=QH2-TGUlwu4`. |
| `4-not_found_page_404` | Fresh-machine setup: everything from task 3 plus a custom 404 page containing `Ceci n'est pas une page`. |
| `5-design_a_beautiful_404_page.html` | A self-contained, responsive 404 page (a gallery-style homage to Magritte's *La Trahison des images*) that keeps the phrase `Ceci n'est pas une page`. |

Tasks 3 and 4 each install and fully configure Nginx themselves, so they work on a
brand-new Ubuntu machine without first running an earlier script. Each one rewrites
`/etc/nginx/sites-available/default`, which means you can run them in any order and
the last script you run decides the final configuration.

## Usage

```bash
./0-transfer_file some_page.html 8.8.8.8 ubuntu ~/.ssh/school
sudo ./1-install_nginx_web_server     # or run as root
sudo ./3-redirection
sudo ./4-not_found_page_404
```

Quick checks after running on the server:

```bash
curl localhost                         # Holberton School
curl -sI localhost/redirect_me         # HTTP/1.1 301 Moved Permanently + Location header
curl -s localhost/nope                 # Ceci n'est pas une page
curl -s -o /dev/null -w '%{http_code}\n' localhost/nope   # 404
```

To use the designed page as the real 404 page, copy it over the plain one:

```bash
sudo cp 5-design_a_beautiful_404_page.html /var/www/html/custom_404.html
```

## Task 2: domain name (manual steps)

1. Get a domain, for example a free one from a provider your course recommends, or a `.tech` domain from the student pack.
2. In the registrar's DNS settings, add an **A record** for the root domain (`@`) pointing to your web-01 server's IP address.
3. Wait for DNS to update, then check it: `dig yourdomain.tech` should show your server IP in the `ANSWER SECTION`.
4. Add the domain to your ALU/Holberton intranet profile (the project page links to it).
5. If the registrar sends a verification email, confirm it so the domain is not suspended.
6. Write the root domain into the answer file with no subdomain, for example:
   `echo "yourdomain.tech" > 2-setup_a_domain_name`
