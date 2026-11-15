#!/usr/bin/env fish

set binary git-cache-proxy
set nspawn_file /etc/systemd/nspawn/$binary.spawn
set cache_dir /var/cache/$binary

run_mkosi build (status dirname | path resolve)
or return

set nspawn_file_text "[Exec]
Boot=yes
Hostname=$binary
PrivateUsers=pick

[Files]
Bind=$cache_dir
PrivateUsersOwnership=auto

[Network]
VirtualEthernet=no"
if test (cat $nspawn_file 2>/dev/null) != $nspawn_file_text
    header "Updating "(path basename $nspawn_file)

    echo "$nspawn_file_text" | run0 tee $nspawn_file
    or return
end

if not test -d $cache_dir
    header "Preparing $cache_dir"

    run0 mkdir -v $cache_dir
    or return

    run0 chmod -v 777 $cache_dir
    or return
end
