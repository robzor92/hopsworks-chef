require 'json'
require 'base64'
require 'digest'

my_ip = my_private_ip()
domain_name="domain1"
domains_dir = node['hopsworks']['domains_dir']
theDomain="#{domains_dir}/#{domain_name}"
mysql_user=node['mysql']['user']
mysql_password=node['mysql']['password']
password_file = "#{theDomain}_admin_passwd"

featurestore_user=node['featurestore']['user']
featurestore_password=node['featurestore']['password']

mysql_host = private_recipe_ip("ndb","mysqld")
featurestore_jdbc_url = node['featurestore']['jdbc_url']
# In case of an upgrade, attribute-driven-domain will not run but we still need to configure
# connection pool for the online featurestore
if node['featurestore']['jdbc_url'].eql? "localhost"
  featurestore_jdbc_url="jdbc:mysql://#{mysql_host}:#{node['ndb']['mysql_port']}/"
end


bash "systemd_reload_for_glassfish_failures" do
  user "root"
  ignore_failure true
  code <<-EOF
    systemctl stop glassfish-#{domain_name}
    systemctl daemon-reload
  EOF
end

if node['hopsworks']['systemd'] == "true"
  systemd = true
else
  systemd = false
end

group node['hopsworks']['group'] do
  action :create
  not_if "getent group #{node['hopsworks']['group']}"
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

group node['jupyter']['group'] do
  action :create
  not_if "getent group #{node['jupyter']['group']}"
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

group node['serving']['group'] do
  action :create
  not_if "getent group #{node['serving']['group']}"
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

#
# hdfs superuser group is 'hdfs'
#
group node['hops']['hdfs']['user'] do
  action :create
  not_if "getent group #{node['hops']['hdfs']['user']}"
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

user node['hopsworks']['user'] do
  home "/home/#{node['hopsworks']['user']}"
  gid node['hopsworks']['group']
  action :create
  shell "/bin/bash"
  manage_home true
  not_if "getent passwd #{node['hopsworks']['user']}"
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

group node['jupyter']['group'] do
  action :modify
  members ["#{node['hopsworks']['user']}"]
  append true
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

group node['serving']['group'] do
  action :modify
  members ["#{node['hopsworks']['user']}"]
  append true
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

group node['jupyter']['group'] do
  action :modify
  members ["#{node['hopsworks']['user']}"]
  append true
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

group node['conda']['group'] do
  action :modify
  members ["#{node['hopsworks']['user']}"]
  append true
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

# Add to the hdfs superuser group
group node['hops']['hdfs']['user'] do
  action :modify
  members ["#{node['hopsworks']['user']}"]
  append true
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

user node['jupyter']['user'] do
  home node['jupyter']['base_dir']
  gid node['jupyter']['group']
  action :create
  shell "/bin/bash"
  manage_home true
  not_if "getent passwd #{node['jupyter']['user']}"
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

user node['serving']['user'] do
  gid node['serving']['group']
  action :create
  shell "/bin/bash"
  manage_home true
  not_if "getent passwd #{node['serving']['user']}"
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

group node['kagent']['certs_group'] do
  action :modify
  members ["#{node['hopsworks']['user']}"]
  append true
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

group node['hops']['group'] do
  action :modify
  members ["#{node['hopsworks']['user']}", "#{node['jupyter']['user']}", "#{node['serving']['user']}"]
  append true
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

#update permissions of base_dir to 770
directory node['jupyter']['base_dir']  do
  owner node['jupyter']['user']
  group node['jupyter']['group']
  mode "770"
  action :create
end

directory node['hopsworks']['dir']  do
  owner node['hopsworks']['user']
  group node['hopsworks']['group']
  mode "755"
  action :create
  not_if "test -d #{node['hopsworks']['dir']}"
end

directory domains_dir  do
  owner node['hopsworks']['user']
  group node['hopsworks']['group']
  mode "750"
  action :create
  not_if "test -d #{domains_dir}"
end


# For unzipping files
dtrx=""
case node['platform_family']
when "debian"

  if node['platform_version'].to_f <= 14.04
    node.override['hopsworks']['systemd'] = "false"
  end
  package ["dtrx", "libkrb5-dev"]

  dtrx="dtrx"
when "rhel"
  package ["krb5-libs", "p7zip"]

  remote_file "#{Chef::Config['file_cache_path']}/dtrx.tar.gz" do
    user node['glassfish']['user']
    group node['glassfish']['group']
    source node['dtrx']['download_url']
    mode 0755
    action :create
  end

  bash "unpack_dtrx" do
    user "root"
    code <<-EOF
      set -e
      cd #{Chef::Config['file_cache_path']}
      tar -xzf dtrx.tar.gz
      cd dtrx-7.1
      python setup.py install --prefix=/usr/local
      # dtrx expects 7z to on its path. create a symbolic link from /bin/7z to /bin/7za
      rm -f /bin/7z
      ln -s /bin/7za /bin/7z
    EOF
    not_if "which dtrx"
  end
  dtrx="/usr/local/bin/dtrx"
end

# Install authbind to allow glassfish to bind on ports < 1024
case node['platform_family']
when "debian"
  package "authbind"
when "rhel"
  authbind_rpm = ::File.basename(node['authbind']['download_url'])

  remote_file "#{Chef::Config['file_cache_path']}/#{authbind_rpm}" do
    user node['glassfish']['user']
    group node['glassfish']['group']
    source node['authbind']['download_url']
    mode 0755
    action :create
  end

  package 'authbind' do
    source "#{Chef::Config['file_cache_path']}/#{authbind_rpm}"
  end
end

# Configure authbind ports
authbind_port "Authbind Glassfish Admin port" do
  port node['hopsworks']['admin']['port'].to_i
  user node['glassfish']['user']
  only_if {node['hopsworks']['admin']['port'].to_i < 1024}
end

authbind_port "Authbind Glassfish https port" do
  port node['hopsworks']['https']['port'].to_i
  user node['glassfish']['user']
  only_if {node['hopsworks']['https']['port'].to_i < 1024}
end

file "#{node['hopsworks']['env_var_file']}" do
  content '# Generated by Chef. Environment variable exported for glassfish-domain1'
  mode 0700
  owner node['glassfish']['user']
  group node['glassfish']['group']
end


node.override = {
  'java' => {
    'install_flavor' => node['java']['install_flavor'],
    'jdk_version' => node['java']['jdk_version']
  },
  'glassfish' => {
    'version' => node['glassfish']['version'],
    'domains_dir' => node['hopsworks']['domains_dir'],
    'domains' => {
      domain_name => {
        'config' => {
          'systemd_enabled' => systemd,
          'systemd_start_timeout' => 900,
          'min_memory' => node['glassfish']['min_mem'],
          'max_memory' => node['glassfish']['max_mem'],
          'max_perm_size' => node['glassfish']['max_perm_size'],
          'max_stack_size' => node['glassfish']['max_stack_size'],
          'port' => 8080, #This is hardcoded as it's not used. Http listener is disabled in hopsworks::default.
          'https_port' => node['hopsworks']['https']['port'].to_i,
          'admin_port' => node['hopsworks']['admin']['port'].to_i,
          'username' => node['hopsworks']['admin']['user'],
          'password' => node['hopsworks']['admin']['password'],
          'master_password' => node['hopsworks']['master']['password'],
          'remote_access' => false,
          'secure' => false,
          'environment_file' => node['hopsworks']['env_var_file'],
          'jvm_options' => ["-DHADOOP_HOME=#{node['hops']['dir']}/hadoop", "-DHADOOP_CONF_DIR=#{node['hops']['dir']}/hadoop/etc/hadoop", '-Dcom.sun.enterprise.tools.admingui.NO_NETWORK=true', '-Dlog4j.configuration=file:///${com.sun.aas.instanceRoot}/config/log4j.properties']
        },
        'extra_libraries' => {
          'jdbcdriver' => {
            'type' => 'common',
            'url' => node['hopsworks']['mysql_connector_url']
          }
        },
        'threadpools' => {
          'thread-pool-1' => {
            'maxthreadpoolsize' => 200,
            'minthreadpoolsize' => 5,
            'idletimeout' => 900,
            'maxqueuesize' => 4096
          },
          'http-thread-pool' => {
            'maxthreadpoolsize' => 200,
            'minthreadpoolsize' => 5,
            'idletimeout' => 900,
            'maxqueuesize' => 4096
          },
          'admin-pool' => {
            'maxthreadpoolsize' => 40,
            'minthreadpoolsize' => 5,
            'maxqueuesize' => 256
          }
        },
        'managed_thread_factories' => {
          'concurrent/hopsThreadFactory' => {
            'threadpriority' => 10,
            'description' => 'Hopsworks Thread Factory'
          }
        },
        'managed_executor_services' => {
          'concurrent/hopsExecutorService' => {
            'threadpriority' => 10,
            'corepoolsize' => 50,
            'maximumpoolsize' => 400,
            'taskqueuecapacity' => 20000,
            'description' => 'Hopsworks Executor Service'
          }
        },
        'managed_scheduled_executor_services' => {
          'concurrent/hopsScheduledExecutorService' => {
            'corepoolsize' => 10,
            'description' => 'Hopsworks Executor Service'
          }
        },
        'jdbc_connection_pools' => {
          'hopsworksPool' => {
            'config' => {
              'datasourceclassname' => 'com.mysql.jdbc.jdbc2.optional.MysqlDataSource',
              'restype' => 'javax.sql.DataSource',
              'isconnectvalidatereq' => 'true',
              'validationmethod' => 'auto-commit',
              'ping' => 'true',
              'description' => 'Hopsworks Connection Pool',
              'properties' => {
                'Url' => "jdbc:mysql://#{my_ip}:3306/",
                'User' => mysql_user,
                'Password' => mysql_password
              }
            },
            'resources' => {
              'jdbc/hopsworks' => {
                'description' => 'Resource for Hopsworks Pool',
              }
            }
          },
          'featureStorePool' => {
            'config' => {
              'datasourceclassname' => 'com.mysql.jdbc.jdbc2.optional.MysqlDataSource',
              'restype' => 'javax.sql.DataSource',
              'isconnectvalidatereq' => 'true',
              'validationmethod' => 'auto-commit',
              'ping' => 'true',
              'description' => 'FeatureStore Connection Pool',
              'properties' => {
                'Url' => featurestore_jdbc_url,
                'User' => featurestore_user,
                'Password' => featurestore_password
              }
            },
            'resources' => {
              'jdbc/featurestore' => {
                'description' => 'Resource for Hopsworks Pool',
              }
            }
          },
          'airflowPool' => {
            'config' => {
              'datasourceclassname' => 'com.mysql.jdbc.jdbc2.optional.MysqlDataSource',
              'restype' => 'javax.sql.DataSource',
              'isconnectvalidatereq' => 'true',
              'validationmethod' => 'auto-commit',
              'ping' => 'true',
              'description' => 'Airflow Connection Pool',
              'properties' => {
                'Url' => "jdbc:mysql://#{my_ip}:3306/",
                'User' => node['airflow']['mysql_user'],
                'Password' => node['airflow']['mysql_password']
              }
            },
            'resources' => {
              'jdbc/airflow' => {
                'description' => 'Resource for Airflow Pool',
              }
            }
          },
          'ejbTimerPool' => {
            'config' => {
              'datasourceclassname' => 'com.mysql.jdbc.jdbc2.optional.MysqlDataSource',
              'restype' => 'javax.sql.DataSource',
              'isconnectvalidatereq' => 'true',

              'validationmethod' => 'auto-commit',
              'ping' => 'true',
              'description' => 'Hopsworks Connection Pool',
              'properties' => {
                'Url' => "jdbc:mysql://#{my_ip}:3306/glassfish_timers",
                'User' => mysql_user,
                'Password' => mysql_password
              }
            },
            'resources' => {
              'jdbc/hopsworksTimers' => {
                'description' => 'Resource for Hopsworks EJB Timers Pool',
              }
            }
          }
        }
      }
    }
  }
}


include_recipe 'glassfish::default'
package 'openssl'

if !::File.directory?("#{theDomain}/lib")
  include_recipe 'glassfish::attribute_driven_domain'
else
  # For older installations (Hopsworks <= 1.0.0) the paths referring to glassfish contain the glassfish version 
  # this is problematic during upgrades. We replace them here with sed. 
  ["glassfish-4.1.2.174", "glassfish-4.1.2.181"].each do |version|
    bash "remove_glassfish_versions" do 
      user "root"
      group "root"
      code <<-EOL
        sed -i 's/#{version}/current/g' /lib/systemd/system/glassfish-#{domain_name}.service
        sed -i 's/#{version}/current/g' #{theDomain}/config/domain.xml
        sed -i 's/#{version}/current/g' #{theDomain}/bin/domain1_asadmin
      EOL
    end
  end
end 

cauth = File.basename(node['hopsworks']['cauth_url'])

remote_file "#{theDomain}/lib/#{cauth}"  do
  user node['glassfish']['user']
  group node['glassfish']['group']
  source node['hopsworks']['cauth_url']
  mode 0755
  action :create_if_missing
end

template "#{theDomain}/docroot/404.html" do
  source "404.html.erb"
  owner node['glassfish']['user']
  group node['glassfish']['group']
  mode "444"
  action :create
end

cookbook_file"#{theDomain}/docroot/hops_icon.png" do
  source 'hops_icon.png'
  owner node['glassfish']['user']
  group node['glassfish']['group']
  mode '0755'
  action :create_if_missing
end

if systemd == true
  directory "/etc/systemd/system/glassfish-#{domain_name}.service.d" do
    owner "root"
    group "root"
    mode "755"
    action :create
  end


   template "/etc/systemd/system/glassfish-#{domain_name}.service.d/limits.conf" do
     source "limits.conf.erb"
     owner "root"
     mode 0774
     action :create
   end

ulimit_domain node['hopsworks']['user'] do
  rule do
    item :memlock
    type :soft
    value "unlimited"
  end
  rule do
    item :memlock
    type :hard
    value "unlimited"
  end
end




  hopsworks_grants "reload_systemd" do
    tables_path  ""
    views_path ""
    rows_path  ""
    action :reload_systemd
  end

end

ca_dir = node['certs']['dir']

directory ca_dir do
  owner node['glassfish']['user']
  group node['kagent']['certs_group']
  mode "750"
  action :create
end

master_password_digest = Digest::SHA256.hexdigest node['hopsworks']['encryption_password']

file "#{ca_dir}/encryption_master_password" do
  content "#{master_password_digest}"
  mode "0700"
  owner node['glassfish']['user']
  group node['glassfish']['group']
end

directory "#{ca_dir}/transient" do
  owner node['glassfish']['user']
  group node['kagent']['certs_group']
  mode "750"
  action :create
end

dirs = %w{certs crl newcerts private intermediate}

for d in dirs
  directory "#{ca_dir}/#{d}" do
    owner node['glassfish']['user']
    group node['glassfish']['group']
    mode "700"
    action :create
  end
end

int_dirs = %w{certs crl csr newcerts private}

for d in int_dirs
  directory "#{ca_dir}/intermediate/#{d}" do
    owner node['glassfish']['user']
    group node['glassfish']['group']
    mode "700"
    action :create
  end
end

template "#{ca_dir}/openssl-ca.cnf" do
  source "caopenssl.cnf.erb"
  owner node['glassfish']['user']
  mode "600"
  variables({
              :ca_dir =>  "#{ca_dir}"
            })
  action :create
end

template "#{ca_dir}/intermediate/openssl-intermediate.cnf" do
  source "intermediateopenssl.cnf.erb"
  owner node['glassfish']['user']
  mode "600"
  variables({
              :int_ca_dir =>  "#{ca_dir}/intermediate"
            })
  action :create
end

template "#{theDomain}/bin/ndb_backup.sh" do
  source "ndb_backup.sh.erb"
  owner node['glassfish']['user']
  group node['glassfish']['group']
  mode "754"
  action :create
end

template "#{theDomain}/bin/convert-ipython-notebook.sh" do
  source "convert-ipython-notebook.sh.erb"
  owner node['glassfish']['user']
  group node['glassfish']['group']
  mode "550"
  action :create
end

template "#{theDomain}/bin/jupyter.sh" do
  source "jupyter.sh.erb"
  owner node['glassfish']['user']
  group node['glassfish']['group']
  mode "550"
  action :create
end

template "#{theDomain}/bin/jupyter-project-cleanup.sh" do
  source "jupyter-project-cleanup.sh.erb"
  owner node['glassfish']['user']
  group node['glassfish']['group']
  mode "550"
  action :create
end

template "#{theDomain}/bin/jupyter-kill.sh" do
  source "jupyter-kill.sh.erb"
  owner node['glassfish']['user']
  group node['jupyter']['group']
  mode "550"
  action :create
end

template "#{theDomain}/bin/jupyter-stop.sh" do
  source "jupyter-stop.sh.erb"
  owner node['glassfish']['user']
  group node['jupyter']['group']
  mode "550"
  action :create
end

template "#{theDomain}/bin/jupyter-launch.sh" do
  source "jupyter-launch.sh.erb"
  owner node['glassfish']['user']
  group node['jupyter']['group']
  mode "550"
  action :create
end

template "#{theDomain}/bin/tfserving.sh" do
  source "tfserving.sh.erb"
  owner node['glassfish']['user']
  group node['serving']['group']
  mode "550"
  action :create
end

template "#{theDomain}/bin/tfserving-kill.sh" do
  source "tfserving-kill.sh.erb"
  owner node['glassfish']['user']
  group node['serving']['group']
  mode "550"
  action :create
end

template "#{theDomain}/bin/sklearn_flask_server.py" do
  source "sklearn_flask_server.py.erb"
  owner node['glassfish']['user']
  group node['serving']['group']
  mode "550"
  action :create
end

template "#{theDomain}/bin/sklearn_serving-launch.sh" do
  source "sklearn_serving-launch.sh.erb"
  owner node['glassfish']['user']
  group node['serving']['group']
  mode "550"
  action :create
end

template "#{theDomain}/bin/sklearn_serving.sh" do
  source "sklearn_serving.sh.erb"
  owner node['glassfish']['user']
  group node['serving']['group']
  mode "550"
  action :create
end

template "#{theDomain}/bin/sklearn_serving-kill.sh" do
  source "sklearn_serving-kill.sh.erb"
  owner node['glassfish']['user']
  group node['serving']['group']
  mode "550"
  action :create
end

template "#{theDomain}/bin/anaconda-prepare.sh" do
  source "anaconda-prepare.sh.erb"
  owner node['glassfish']['user']
  group node['glassfish']['group']
  mode "550"
  action :create
end

template "#{theDomain}/bin/anaconda-rsync.sh" do
  source "anaconda-rsync.sh.erb"
  owner node['glassfish']['user']
  group node['glassfish']['group']
  mode "550"
  action :create
end

command=""
case node['platform']
 when 'debian', 'ubuntu'
   command='tensorflow_model_server'
 when 'redhat', 'centos', 'fedora'
   command='/opt/serving/bazel-bin/tensorflow_serving/model_servers/tensorflow_model_server'
end


template "#{theDomain}/bin/tfserving-launch.sh" do
  source "tfserving-launch.sh.erb"
  owner node['glassfish']['user']
  group node['serving']['group']
  mode "550"
  variables({
     :command => command
  })
  action :create
end

template "#{theDomain}/bin/zip-hdfs-files.sh" do
  source "zip-hdfs-files.sh.erb"
  owner node['glassfish']['user']
  group node['glassfish']['group']
  mode "550"
  action :create
end

template "#{theDomain}/bin/zip-background.sh" do
  source "zip-background.sh.erb"
  owner node['glassfish']['user']
  group node['glassfish']['group']
  mode "550"
  action :create
end

template "#{theDomain}/bin/unzip-hdfs-files.sh" do
  source "unzip-hdfs-files.sh.erb"
  owner node['glassfish']['user']
  group node['glassfish']['group']
  mode "550"
  variables(lazy {
    h = {}
    h['dtrx'] = dtrx
    h
  })
  action :create
end

template "#{theDomain}/bin/unzip-background.sh" do
  source "unzip-background.sh.erb"
  owner node['glassfish']['user']
  group node['glassfish']['group']
  mode "550"
  action :create
end

template "#{theDomain}/bin/global-ca-sign-csr.sh" do
  source "global-ca-sign-csr.sh.erb"
  owner node['glassfish']['user']
  mode 0550
  action :create
end

template "#{theDomain}/bin/ca-keystore.sh" do
  source "ca-keystore.sh.erb"
  owner node['glassfish']['user']
  mode 0550
  action :create
  variables({
         :directory => node["hopssite"]["keystore_dir"],
  })
end

template "#{theDomain}/bin/start-llap.sh" do
  source "start-llap.sh.erb"
  owner node['glassfish']['user']
  group node['hive2']['group']
  mode 0550
  action :create
end

template "#{theDomain}/bin/dump_web_logs_to_hdfs.sh" do
  source "dump_web_logs_to_hdfs.sh.erb"
  owner node['glassfish']['user']
  group node['glassfish']['group']
  mode 0700
  action :create
  variables({
              :weblogs_dir => "#{theDomain}/logs/access",
              :hadoop_home => node['hops']['base_dir'],
              :remote_weblogs_dir => "#{node['hops']['hdfs']['user_home']}/#{node['glassfish']['user']}/webserver_logs"
            })
end

template "/etc/sudoers.d/glassfish" do
  source "glassfish_sudoers.erb"
  owner "root"
  group "root"
  mode "0440"
  variables({
              :user => node['glassfish']['user'],
              :ndb_backup =>  "#{theDomain}/bin/ndb_backup.sh",
              :jupyter =>  "#{theDomain}/bin/jupyter.sh",
              :tfserving =>  "#{theDomain}/bin/tfserving.sh",
              :sklearn_serving =>  "#{theDomain}/bin/sklearn_serving.sh",
              :tensorboard =>  "#{theDomain}/bin/tensorboard.sh",
              :jupyter_cleanup =>  "#{theDomain}/bin/jupyter-project-cleanup.sh",
              :jupyter_kernel =>  "#{theDomain}/bin/jupyter-install-kernel.sh",
              :global_ca_sign =>  "#{theDomain}/bin/global-ca-sign-csr.sh",
              :ca_keystore => "#{theDomain}/bin/ca-keystore.sh",
              :hive_user => node['hive2']['user'],
              :anaconda_prepare => "#{theDomain}/bin/anaconda-prepare.sh",
              :start_llap => "#{theDomain}/bin/start-llap.sh"
            })
  action :create
end

# Replace sysv with our version. It increases the max number of open files limit (ulimit -n)
case node['platform']
when "ubuntu"
  file "/etc/init.d/glassfish-#{domain_name}" do
    owner "root"
    action :delete
  end

  template "/etc/init.d/glassfish-#{domain_name}" do
    source "glassfish.erb"
    owner "root"
    mode 0744
    action :create
    variables({
                :domain_name =>  domain_name,
                :password_file => password_file
              })

  end

end


#
# Jupyter Configuration
#


# Hopsworks user should own the directory so that hopsworks code
# can create the template files needed for Jupyter.
# Hopsworks will use a sudoer script to launch jupyter as the 'jupyter' user.
# The jupyter user will be able to read the files and write to the directories due to group permissions

user node["jupyter"]["user"] do
  home node["jupyter"]["base_dir"]
  gid node["jupyter"]["group"]
  action :create
  shell "/bin/bash"
  manage_home true
  not_if "getent passwd #{node["jupyter"]["user"]}"
  not_if { node['install']['external_users'].casecmp("true") == 0 }
end

#update permissions of base_dir to 770
directory node["jupyter"]["base_dir"]  do
  owner node["jupyter"]["user"]
  group node["jupyter"]["group"]
  mode "770"
  action :create
end

directory node["hopssite"]["certs_dir"] do
  owner node["glassfish"]["user"]
  group node['kagent']['certs_group']
  mode "750"
  action :create
end

directory node["hopssite"]["keystore_dir"] do
  owner node["glassfish"]["user"]
  mode "750"
  action :create
end

template "#{theDomain}/config/ca.ini" do
  source "ca.ini.erb"
  owner node['glassfish']['user']
  mode 0750
  action :create
end

template "#{theDomain}/bin/csr-ca.py" do
  source "csr-ca.py.erb"
  owner node['glassfish']['user']
  mode 0750
  action :create
end

flyway_tgz = File.basename(node['hopsworks']['flyway_url'])
flyway =  "flyway-" + node['hopsworks']['flyway']['version']

remote_file "#{Chef::Config['file_cache_path']}/#{flyway_tgz}" do
  user node['glassfish']['user']
  group node['glassfish']['group']
  source node['hopsworks']['flyway_url']
  mode 0755
  action :create
end

bash "unpack_flyway" do
  user "root"
  code <<-EOF
    set -e
    cd #{Chef::Config['file_cache_path']}
    tar -xzf #{flyway_tgz}
    mv #{flyway} #{theDomain}
    cd #{theDomain}
    chown -R #{node['glassfish']['user']} flyway*
    rm -rf flyway
    ln -s #{flyway} flyway
  EOF
  not_if { ::File.exists?("#{theDomain}/flyway/flyway") }
end

template "#{theDomain}/flyway/conf/flyway.conf" do
  source "flyway.conf.erb"
  owner node['glassfish']['user']
  mode 0750
  variables({
              :mysql_host => my_ip
            })
  action :create
end

template "#{theDomain}/flyway/flyway-undo.sh" do
  source "flyway-undo.sh.erb"
  owner node['glassfish']['user']
  mode 0750
  action :create
end

directory "#{theDomain}/flyway/undo" do
  owner node['glassfish']['user']
  mode "770"
  action :create
end

directory "#{theDomain}/flyway/dml" do
  owner node['glassfish']['user']
  mode "770"
  action :create
end

directory "#{theDomain}/flyway/dml/undo" do
  owner node['glassfish']['user']
  mode "770"
  action :create
end

template "#{theDomain}/bin/anaconda-command-ssh.sh" do
  source "anaconda-command-ssh.sh.erb"
  owner node['glassfish']['user']
  group node['glassfish']['group']
  mode 0750
  action :create
end

template "#{theDomain}/bin/conda-command-ssh.sh" do
  source "conda-command-ssh.sh.erb"
  owner node['glassfish']['user']
  group node['glassfish']['group']
  mode 0750
  action :create
end

