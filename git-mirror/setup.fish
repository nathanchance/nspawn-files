#!/usr/bin/env fish

set container_name git-mirror
set nspawn_file /etc/systemd/nspawn/$container_name.nspawn
set data_dir /var/lib/$container_name

run_mkosi build (status dirname | path resolve)
or return

set nspawn_bind_val $data_dir:$data_dir:idmap
set old_nspawn_file_text (cat $nspawn_file 2>/dev/null)
set new_nspawn_file_text "[Exec]
Boot=yes
Hostname=$container_name
PrivateUsers=pick

[Files]
Bind=$nspawn_bind_val
PrivateUsersOwnership=auto

[Network]
VirtualEthernet=no"
if not test -e $nspawn_file; or test "$old_nspawn_file_text" != "$new_nspawn_file_text"
    header "Updating "(path basename $nspawn_file)

    echo "$new_nspawn_file_text" | run0 tee $nspawn_file
    or return
end

if not test -d $data_dir
    header "Preparing $data_dir"

    run0 mkdir -v $data_dir
    or return

    run0 chmod -v 777 $data_dir
    or return
end

set llvm_project $data_dir/llvm/llvm-project.git

run0 systemd-nspawn \
    --machine=$container_name \
    --register=no \
    --quiet \
    --settings=no \
    --as-pid2 \
    --private-users=pick \
    --bind=$nspawn_bind_val \
    --private-users-ownership=auto \
    /usr/bin/bash \
    -c "set -ex

sed -i 's;^Listen 80;Listen 50000;g' /etc/httpd/conf/httpd.conf

systemd-tmpfiles --create /etc/tmpfiles.d/00-git-mirror.conf

grok-pull -c /etc/grokmirror/grokmirror.conf -v

if [ ! -f '$data_dir/fsck.status.js' ]; then
    grok-fsck -c /etc/grokmirror/grokmirror.conf -f -v
fi

if [ -d '$llvm_project' ]; then
    grok-dumb-pull '$llvm_project'
else
    git clone --mirror https://github.com/llvm/llvm-project.git '$llvm_project'
fi"
or return

# 48 is Fedora's apache user
run0 chown -R 48:48 $data_dir
