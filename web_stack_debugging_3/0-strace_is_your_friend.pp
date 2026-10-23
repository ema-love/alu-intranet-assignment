# Fixes the Apache 500 error found with strace: wp-settings.php requires
# "class-wp-locale.phpp", which does not exist (ENOENT). The real file is "class-wp-locale.php".
exec { 'fix-wordpress-locale-typo':
  command => "sed -i 's/class-wp-locale\\.phpp/class-wp-locale.php/' /var/www/html/wp-settings.php",
  path    => ['/bin', '/usr/bin'],
  onlyif  => "grep -q 'class-wp-locale\\.phpp' /var/www/html/wp-settings.php",
  notify  => Exec['reload-apache'],
}

# Reload Apache only when the file was changed, so PHP does not keep serving a cached copy
exec { 'reload-apache':
  command     => 'apache2ctl graceful',
  path        => ['/usr/sbin', '/usr/bin', '/bin'],
  refreshonly => true,
}
