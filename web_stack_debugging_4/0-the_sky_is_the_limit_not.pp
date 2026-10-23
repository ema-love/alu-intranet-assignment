# Raises the open-file limit Nginx is started with. /etc/default/nginx set ULIMIT="-n 15",
# so each worker could hold only 15 files and sockets, and requests failed with
# "Too many open files" under load (ab -c 100 -n 2000). 4096 covers worker_connections 768
# (about 2 files per connection) with headroom.
exec { 'raise-nginx-ulimit':
  command => "sed -i 's/^#\\?ULIMIT=.*/ULIMIT=\"-n 4096\"/' /etc/default/nginx",
  path    => ['/bin', '/usr/bin'],
  unless  => "grep -q '^ULIMIT=\"-n 4096\"' /etc/default/nginx",
  notify  => Exec['restart-nginx'],
}

# The limit only applies to newly started processes, so restart Nginx, but only after a change
exec { 'restart-nginx':
  command     => 'service nginx restart',
  path        => ['/usr/sbin', '/usr/bin', '/sbin', '/bin'],
  refreshonly => true,
}
