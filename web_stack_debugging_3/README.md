# Web stack debugging #3: strace is your friend

Answer file for the ALU / Holberton **Web stack debugging #3** project.

| File | What it is |
| --- | --- |
| `0-strace_is_your_friend.pp` | Puppet manifest that fixes a one-word typo in `/var/www/html/wp-settings.php`, then reloads Apache only if it changed something. |

## Finding the cause with strace

`curl -sI 127.0.0.1` returns `HTTP/1.0 500 Internal Server Error` with an empty body, while
`service apache2 status` says Apache is running and `apache2ctl configtest` says `Syntax OK`.

Attach `strace` to every Apache worker, make one request, and look for failed system calls:

```bash
strace -f -e trace=file $(pgrep -u www-data apache2 | sed 's/^/-p /') -o /tmp/trace.txt &
curl -s 127.0.0.1/ > /dev/null
grep -E '= -1 E(NOENT|ACCES)' /tmp/trace.txt
```

(You can also run strace in one tmux pane and curl in another.)

The request failed while doing this:

```
lstat("/var/www/html/wp-includes/class-wp-locale.phpp", ...) = -1 ENOENT (No such file or directory)
openat(AT_FDCWD, "/var/www/html/wp-includes/class-wp-locale.phpp", O_RDONLY) = -1 ENOENT (No such file or directory)
```

- `ENOENT` means *no such file*. Note the extension: `.phpp`.
- The real file is `/var/www/html/wp-includes/class-wp-locale.php`.
- `grep -n class-wp-locale /var/www/html/wp-settings.php` shows line 147 asking for
  `class-wp-locale.phpp`.
- There are no `EACCES`/`EPERM` (permission) failures, so ownership and permissions are fine.
  The other `ENOENT` lines are normal: Apache looks for `index.html` before `index.php`, and
  WordPress checks for optional files such as `wp-content/db.php`.

WordPress uses `require_once` on that file, so when it is missing PHP stops with a fatal
error, and Apache turns that into **500 Internal Server Error**.

## The Puppet fix

```puppet
exec { 'fix-wordpress-locale-typo':
  command => "sed -i 's/class-wp-locale\\.phpp/class-wp-locale.php/' /var/www/html/wp-settings.php",
  path    => ['/bin', '/usr/bin'],
  onlyif  => "grep -q 'class-wp-locale\\.phpp' /var/www/html/wp-settings.php",
  notify  => Exec['reload-apache'],
}

exec { 'reload-apache':
  command     => 'apache2ctl graceful',
  path        => ['/usr/sbin', '/usr/bin', '/bin'],
  refreshonly => true,
}
```

- **`exec` + `sed`** changes exactly the misspelled word and nothing else in the file.
- **`onlyif`** runs the `sed` only while the typo is still there, so running Puppet again
  changes nothing.
- **`notify` + `refreshonly`** reloads Apache only when the fix actually ran.
  `apache2ctl graceful` lets in-progress requests finish.

Why reload at all? PHP keeps compiled files in memory (OPcache) and, with Ubuntu's
default `opcache.revalidate_freq = 2`, only re-checks them every 2 seconds. In testing, without
the reload the page **still returned 500 right after the fix** and only recovered a few
seconds later. The reload clears that cache, so the fix works on the very next request.

## Tests

Run in a Docker reproduction, because the original sandbox is only available from the intranet.
The reproduction is Ubuntu 20.04 with Apache 2.4.41, PHP 7.4 (OPcache on), MariaDB and WordPress
(Ubuntu package), installed with the site title "Holberton". The documented sandbox fault
(`class-wp-locale.php` → `class-wp-locale.phpp` in `wp-settings.php`) was then introduced.

| Check | Result |
| --- | --- |
| `puppet parser validate` (Puppet 5.5.10) | OK |
| `puppet-lint` 2.4.2 | no warnings |
| Before | `500` |
| 1st `puppet apply --detailed-exitcodes` | exit `2` (changed): typo fixed, Apache reload triggered once |
| `curl` immediately after | `200`, body contains `Holberton` (`<title>Holberton – Just another WordPress site</title>`) |
| 10 further requests | all `200` |
| Apache error log after the fix | only `AH00171: Graceful restart requested`, no PHP errors |
| 2nd `puppet apply` | exit `0` (no changes, no reload), still `200` |

In this reproduction, PHP errors also appear in `/var/log/apache2/error.log`; the original
sandbox reportedly logs nothing, which is why strace is needed there.
