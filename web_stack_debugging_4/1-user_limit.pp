# Lets the holberton user open files again. /etc/security/limits.conf gave it a soft limit of 4
# and a hard limit of 5 open files, but a login shell already uses 3 (stdin, stdout, stderr), so
# logging in and running commands failed with "Too many open files".
# Restore the usual defaults: soft 1024, hard 4096. Applies to new login sessions (pam_limits).
exec { 'raise-holberton-soft-nofile':
  command => "sed -i 's/^holberton\\s\\+soft\\s\\+nofile\\s\\+[0-9]\\+/holberton soft nofile 1024/' /etc/security/limits.conf",
  path    => ['/bin', '/usr/bin'],
  onlyif  => "grep -qE '^holberton\\s+soft\\s+nofile\\s+[0-9]{1,3}\\s*$' /etc/security/limits.conf",
}

exec { 'raise-holberton-hard-nofile':
  command => "sed -i 's/^holberton\\s\\+hard\\s\\+nofile\\s\\+[0-9]\\+/holberton hard nofile 4096/' /etc/security/limits.conf",
  path    => ['/bin', '/usr/bin'],
  onlyif  => "grep -qE '^holberton\\s+hard\\s+nofile\\s+[0-9]{1,3}\\s*$' /etc/security/limits.conf",
}
