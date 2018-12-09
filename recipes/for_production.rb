include_recipe 'selinux::disabled'

execute "add postgresql11 repo" do
  command "yum -y localinstall https://download.postgresql.org/pub/repos/yum/testing/11/redhat/rhel-7-x86_64/pgdg-centos11-11-2.noarch.rpm"
end
  
execute "update yum repo" do
  command "yum -y update"
end

package "epel-release"
package "gcc"
package "gcc-c++"
package "openssl-devel"
package "libyaml-devel"
package "readline-devel"
package "zlib-devel"
package "git"
package "sqlite-devel"

package "vim"
package "wget"
package "nmap"
package "net-tools"
package "bind-utils"

package "postgresql11-server"
package "postgresql11-devel"

service 'firewalld' do
  action [:disable, :stop]
end

execute 'init postgresql' do
  command '/usr/pgsql-11/bin/postgresql-11-setup initdb'
  not_if 'test -n "$(ls -A /var/lib/pgsql/11/data)"'
end

service 'postgresql-11' do
  action [:enable, :start]
end

execute "postgres user new passward" do
  command "echo postgres | passwd --stdin postgres"
end


execute "createuser ykevi -s" do
  user "postgres"
  not_if "psql -c \"select * from pg_user where usename = 'ykevi'\" | grep"
end

remote_file "/etc/yum.repos.d/nginx.repo" do
  source "remote_files/nginx.repo"
end

package "nginx"

service 'nginx' do
  action [:enable, :start]
end

execute "mkdir -p /puma_shared/sockets"
execute "chown ykevi:ykevi /puma_shared"
execute "chown ykevi:ykevi /puma_shared/*"

remote_file "/etc/nginx/conf.d/app-name.conf" do
  source "remote_files/app-name.conf"
end

RBENV_DIR = "/usr/local/rbenv"
RBENV_SCRIPT = "/etc/profile.d/rbenv.sh"

git RBENV_DIR do
  repository "git://github.com/sstephenson/rbenv.git"
end

remote_file RBENV_SCRIPT do
  source "remote_files/rbenv.sh"
end

execute "set owner and mode for #{RBENV_SCRIPT} " do
  command "chown root: #{RBENV_SCRIPT}; chmod 644 #{RBENV_SCRIPT}"
  user "root"
end

execute "reloading bash" do
  command "source ~/.bashrc"
end

execute "mkdir #{RBENV_DIR}/plugins" do
  not_if "test -d #{RBENV_DIR}/plugins"
end

git "#{RBENV_DIR}/plugins/ruby-build" do
  repository "git://github.com/sstephenson/ruby-build.git"
end

node["rbenv"]["versions"].each do |version|
  execute "install ruby #{version}" do
    command "source #{RBENV_SCRIPT}; rbenv install #{version}"
    not_if "source #{RBENV_SCRIPT}; rbenv versions | grep #{version}"
  end
end

execute "set global ruby #{node["rbenv"]["global"]}" do
  command "source #{RBENV_SCRIPT}; rbenv global #{node["rbenv"]["global"]}; rbenv rehash"
  not_if "source #{RBENV_SCRIPT}; rbenv global | grep #{node["rbenv"]["global"]}"
end

node["rbenv"]["gems"].each do |gem|
  execute "gem install #{gem}" do
    command "source #{RBENV_SCRIPT}; gem install #{gem}; rbenv rehash"
    not_if "source #{RBENV_SCRIPT}; gem list | grep #{gem}"
  end
end
