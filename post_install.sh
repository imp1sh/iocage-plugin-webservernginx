#!/usr/bin/env sh

# Packages
# this env is so it doesn't ask
#env ASSUME_ALWAYS_YES=YES pkg install nginx-full php74 php74-extensions php74-composer php74-gd php74-json php74-mbstring php74-mysqli php74-opcache php74-openssl ImageMagick6 php74-pecl-memcache php74-xml php74-zip

# Configurations
# php-fpm
# set php-fpm settings
sed -I '' 's/^listen.*$/listen\ =\ \/var\/run\/php74-fpm.sock/g' /usr/local/etc/php-fpm.d/www.conf
sed -I '' 's/;listen.owner.*$/listen.owner\ =\ www/g' /usr/local/etc/php-fpm.d/www.conf
sed -I '' 's/;listen.group.*$/listen.group\ =\ www/g' /usr/local/etc/php-fpm.d/www.conf
sed -I '' 's/;listen.mode.*$/listen.mode\ =\ 0660/g' /usr/local/etc/php-fpm.d/www.conf

# create php.ini
cp -v /usr/local/etc/php.ini-production /usr/local/etc/php.ini

# set default php parameters
cat <<EOT > /usr/local/etc/php/99-custom.ini
display_errors=Off
safe_mode=Off
safe_mode_exec_dir=
safe_mode_allowed_env_vars=PHP_
expose_php=Off
log_errors=On
error_log=/var/log/nginx/php.scripts.log
register_globals=Off
cgi.force_redirect=0
file_uploads=On
allow_url_fopen=Off
sql.safe_mode=Off
disable_functions=show_source, system, shell_exec, passthru, proc_open, proc_nice, exec
max_execution_time=60
memory_limit=60M
upload_max_filesize=64M
post_max_size=64M
memory_limit=256M
cgi.fix_pathinfo=0
sendmail_path=/usr/sbin/sendmail -fnoc@relaix.net -t
EOT

# Enable and start php-fpm
sysrc php_fpm_enable=YES
service php-fpm start

# NGINX
# set new nginx.conf
mkdir -p /usr/local/www/customer
chown -R www:www /usr/local/www/customer
cp /usr/local/etc/nginx/nginx.conf /usr/local/etc/nginx/nginx.conf.backup
cat <<EOT > /usr/local/etc/nginx/nginx.conf
worker_processes  1;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    sendfile        on;

    keepalive_timeout  65;

    server {
        listen       80;
        server_name  localhost;
        root         /usr/local/www/customer;

        access_log   /var/log/nginx/access.log;
        error_log    /var/log/nginx/error.log;

        location ~ [^/]\.php(/|\$) {
            fastcgi_split_path_info ^(.+?\.php)(/.*)\$;
            if (!-f \$document_root\$fastcgi_script_name) {
                    return 404;
            }

            # Mitigate https://httpoxy.org/ vulnerabilities
            fastcgi_param HTTP_PROXY "";

            fastcgi_pass unix:/var/run/php74-fpm.sock;
            fastcgi_index index.php;

            # include the fastcgi_param setting
            include fastcgi_params;

            # SCRIPT_FILENAME parameter is used for PHP FPM determining
            # the script name.
            fastcgi_param  SCRIPT_FILENAME   \$document_root\$fastcgi_script_name;
        }
    }
}
EOT

# enable and start nginx service
sysrc nginx_enable=YES
service nginx start

