# Web stack debugging #0

Answer file for the ALU / Holberton **Web stack debugging #0** project.

> **Submission note:** the assignment expects this file in the repository
> `alu-system_engineering-devops`, directory `web_stack_debugging_0`. This copy lives in
> `alu-intranet-assignment` as a working copy; copy the folder over before submitting.

| File | What it is |
| --- | --- |
| `0-give_me_a_page` | The command that fixes the container: `service apache2 start`. |

## The problem

```bash
docker run -p 8080:80 -d -it holbertonschool/265-0
curl 0:8080
# curl: (52) Empty reply from server
```

Apache 2 is installed in the container and its page already says `Hello Holberton`, but
Apache is **not running**. Docker accepts the connection on port 8080 and forwards it to
port 80 inside the container, where nothing is listening, so the connection closes with
no reply.

## Investigate and fix (on a machine that can pull the image)

```bash
docker run -p 8080:80 -d -it holbertonschool/265-0
docker ps                                   # note the CONTAINER ID
docker exec -it <CONTAINER_ID> /bin/bash    # get a shell inside the container

# inside the container
service apache2 status                      # * apache2 is not running
ls /var/www/html/                           # the page is already there
cat /var/www/html/index.html
service apache2 start                       # the fix
service apache2 status                      # * apache2 is running
exit

curl 0:8080                                 # Hello Holberton
```

If `service apache2 status` shows something different in your container (for example
Apache is missing, or the page does not contain `Hello Holberton`), stop and check before
submitting: the answer file only covers the "Apache is not running" case.

## Does the fix last?

- `docker stop` + `docker start` of the same container: **no**. Apache is not started
  automatically, so run `service apache2 start` again.
- A new container from the image (`docker run` again): **no**, it starts from the
  original, broken image.
- This is expected for the assignment, which asks to fix the running container. A
  permanent fix would be a new image whose start command launches Apache, for example
  `CMD ["apachectl", "-D", "FOREGROUND"]` in a Dockerfile.
