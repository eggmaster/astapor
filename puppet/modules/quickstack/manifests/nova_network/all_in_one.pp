# Common quickstack configurations
class quickstack::nova_network::all_in_one (
    $admin_email                 = $quickstack::params::admin_email,
    $admin_password              = $quickstack::params::admin_password,
    $ceilometer_metering_secret  = $quickstack::params::ceilometer_metering_secret,
    $ceilometer_user_password    = $quickstack::params::ceilometer_user_password,
    $cinder_db_password          = $quickstack::params::cinder_db_password,
    $cinder_user_password        = $quickstack::params::cinder_user_password,
    $controller_priv_floating_ip = $quickstack::params::controller_priv_floating_ip,
    $controller_pub_floating_ip  = $quickstack::params::controller_pub_floating_ip,
    $fixed_network_range         = $quickstack::params::fixed_network_range,
    $floating_network_range      = $quickstack::params::floating_network_range,
    $glance_db_password          = $quickstack::params::glance_db_password,
    $glance_user_password        = $quickstack::params::glance_user_password,
    $heat_cfn                    = $quickstack::params::heat_cfn,
    $heat_cloudwatch             = $quickstack::params::heat_cloudwatch,
    $heat_db_password            = $quickstack::params::heat_db_password,
    $heat_user_password          = $quickstack::params::heat_user_password,
    $horizon_secret_key          = $quickstack::params::horizon_secret_key,
    $keystone_admin_token        = $quickstack::params::keystone_admin_token,
    $keystone_db_password        = $quickstack::params::keystone_db_password,
    $mysql_host                  = $quickstack::params::mysql_host,
    $mysql_root_password         = $quickstack::params::mysql_root_password,
    $nova_db_password            = $quickstack::params::nova_db_password,
    $nova_user_password          = $quickstack::params::nova_user_password,
    $private_interface           = $quickstack::params::private_interface,
    $public_interface            = $quickstack::params::public_interface,
    $qpid_host                   = $quickstack::params::qpid_host,
    $verbose                     = $quickstack::params::verbose,
) inherits quickstack::params {

    # Configure Nova
    nova_config{
        'DEFAULT/auto_assign_floating_ip':  value => 'True';
        #"DEFAULT/network_host":            value => ${controller_priv_floating_ip;
        "DEFAULT/network_host":             value => "$::ipaddress";
        "DEFAULT/libvirt_inject_partition": value => "-1";
        #"DEFAULT/metadata_host":           value => "$controller_priv_floating_ip";
        "DEFAULT/metadata_host":            value => "$::ipaddress";
        "DEFAULT/multi_host":               value => "True";
        #'DEFAULT/force_dhcp_release':      value => 'False'; #already defined in flatdhcp.pp
    }

    class { 'nova':
        glance_api_servers => "http://${controller_priv_floating_ip}:9292/v1",
        image_service      => 'nova.image.glance.GlanceImageService',
        qpid_hostname      => $qpid_host,
        require            => Class['openstack::db::mysql', 'qpid::server'],
        rpc_backend        => 'nova.openstack.common.rpc.impl_qpid',
        sql_connection     => "mysql://nova:${nova_db_password}@${mysql_host}/nova",
        verbose            => $verbose,
    }

    # uncomment if on a vm
    # GSutclif: Maybe wrap this in a Facter['is-virtual'] test ?
    #file { "/usr/bin/qemu-system-x86_64":
    #    ensure => link,
    #    target => "/usr/libexec/qemu-kvm",
    #    notify => Service["nova-compute"],
    #}
    #nova_config{
    #    "libvirt_cpu_mode": value => "none";
    #}

    class { 'nova::compute::libvirt':
        #libvirt_type                => "qemu",  # uncomment if on a vm
        vncserver_listen            => "$::ipaddress",
    }

    class {"nova::compute":
        enabled => true,
        vncproxy_host => "$controller_priv_floating_ip",
        vncserver_proxyclient_address => "$ipaddress",
    }

    class { 'nova::api':
        enabled           => true,
        admin_password    => "$nova_user_password",
        auth_host         => "$controller_priv_floating_ip",
    }

    class { 'nova::network':
        private_interface => "$private_interface",
        public_interface  => "$public_interface",
        fixed_range       => "$fixed_network_range",
        floating_range    => "$floating_network_range",
        network_manager   => "nova.network.manager.FlatDHCPManager",
        config_overrides  => {"force_dhcp_release" => false},
        create_networks   => true,
        enabled           => true,
        install_service   => true,
    }

    firewall { '001 nova compute incoming':
        proto    => 'tcp',
        dport    => '5900-5999',
        action   => 'accept',
    }

    firewall { '001 controller incoming':
        proto    => 'tcp',
        # need to refine this list
        dport    => ['80', '3306', '5000', '35357', '5672', '8773', '8774', '8775', '8776', '9292', '6080'],
        action   => 'accept',
    }


    # class { 'ceilometer':
    #     metering_secret => $ceilometer_metering_secret,
    #     qpid_hostname   => $qpid_host,
    #     rpc_backend     => 'ceilometer.openstack.common.rpc.impl_qpid',
    #     verbose         => $verbose,
    #     debug           => true,
    # }

    # class { 'quickstack::ceilometer_controller':
    #   ceilometer_metering_secret  => $ceilometer_metering_secret,
    #   ceilometer_user_password    => $ceilometer_user_password,
    #   controller_priv_floating_ip => $controller_priv_floating_ip,
    #   controller_pub_floating_ip  => $controller_pub_floating_ip,
    #   qpid_host                   => $qpid_host,
    #   verbose                     => $verbose,
    # }


    # class { 'ceilometer::agent::compute':
    #     auth_url      => "http://${controller_priv_floating_ip}:35357/v2.0",
    #     auth_password => $ceilometer_user_password,
    # }


    #controller::corosync { 'quickstack': }

    #controller::corosync::node { '10.100.0.2': }
    #controller::corosync::node { '10.100.0.3': }

    #controller::resources::ip { '8.21.28.222':
    #    address => '8.21.28.222',
    #}
    #controller::resources::ip { '10.100.0.222':
    #    address => '10.100.0.222',
    #}

    #controller::resources::lsb { 'qpidd': }

    #controller::stonith::ipmilan { $ipmi_address:
    #    address  => $ipmi_address,
    #    user     => $ipmi_user,
    #    password => $ipmi_pass,
    #    hostlist => $ipmi_host_list,
    #}


    class {'openstack::db::mysql':
        mysql_root_password  => $mysql_root_password,
        keystone_db_password => $keystone_db_password,
        glance_db_password   => $glance_db_password,
        nova_db_password     => $nova_db_password,
        cinder_db_password   => $cinder_db_password,
        neutron_db_password  => '',

        # MySQL
        mysql_bind_address     => '0.0.0.0',
        mysql_account_security => true,

        # neutron
        neutron                => false,

        allowed_hosts          => '%',
        enabled                => true,
    }

    class {'qpid::server':
        auth => "no"
    }

    class {'openstack::keystone':
        db_host                 => $mysql_host,
        db_password             => $keystone_db_password,
        admin_token             => $keystone_admin_token,
        admin_email             => $admin_email,
        admin_password          => $admin_password,
        glance_user_password    => $glance_user_password,
        nova_user_password      => $nova_user_password,
        cinder_user_password    => $cinder_user_password,
        neutron_user_password   => "",

        public_address          => $controller_pub_floating_ip,
        admin_address           => $controller_priv_floating_ip,
        internal_address        => $controller_priv_floating_ip,

        glance_public_address   => $controller_pub_floating_ip,
        glance_admin_address    => $controller_priv_floating_ip,
        glance_internal_address => $controller_priv_floating_ip,

        nova_public_address     => $controller_pub_floating_ip,
        nova_admin_address      => $controller_priv_floating_ip,
        nova_internal_address   => $controller_priv_floating_ip,

        cinder_public_address   => $controller_pub_floating_ip,
        cinder_admin_address    => $controller_priv_floating_ip,
        cinder_internal_address => $controller_priv_floating_ip,

        neutron                 => false,
        enabled                 => true,
        require                 => Class['openstack::db::mysql'],
    }

    class { 'swift::keystone::auth':
        password         => $swift_admin_password,
        public_address   => $controller_pub_floating_ip,
        internal_address => $controller_priv_floating_ip,
        admin_address    => $controller_priv_floating_ip,
    }

    class {'openstack::glance':
        db_host       => $mysql_host,
        user_password => $glance_user_password,
        db_password   => $glance_db_password,
        require       => Class['openstack::db::mysql'],
    }


    class { 'quickstack::cinder_controller':
      cinder_db_password          => $cinder_db_password,
      cinder_user_password        => $cinder_user_password,
      controller_priv_floating_ip => $controller_priv_floating_ip,
      mysql_host                  => $mysql_host,
      qpid_host                   => $qpid_host,
      verbose                     => $verbose,
    }

    class { 'quickstack::heat_controller':
      heat_cfn                    => $heat_cfn,
      heat_cloudwatch             => $heat_cloudwatch,
      heat_user_password          => $heat_user_password,
      heat_db_password            => $heat_db_password,
      controller_priv_floating_ip => $controller_priv_floating_ip,
      controller_pub_floating_ip  => $controller_pub_floating_ip,
      mysql_host                  => $mysql_host,
      qpid_host                   => $qpid_host,
      verbose                     => $verbose,
    }

    # Configure Nova


    class { [ 'nova::scheduler', 'nova::cert', 'nova::consoleauth', 'nova::conductor' ]:
        enabled => true,
    }

    class { 'nova::vncproxy':
        host    => '0.0.0.0',
        enabled => true,
    }

    package {'horizon-packages':
        name   => ['python-memcached', 'python-netaddr'],
        notify => Class['horizon'],
    }

    file {'/etc/httpd/conf.d/rootredirect.conf':
        ensure  => present,
        content => 'RedirectMatch ^/$ /dashboard/',
        notify  => File['/etc/httpd/conf.d/openstack-dashboard.conf'],
    }

    class {'horizon':
        secret_key    => $horizon_secret_key,
        keystone_host => $controller_priv_floating_ip,
    }

    class {'memcached':}

# Double definition - This seems to have appeared with Puppet 3.x
#   class {'apache':}
#   class {'apache::mod::wsgi':}
#   file { '/etc/httpd/conf.d/openstack-dashboard.conf':}


    if ($::selinux != "false"){
      selboolean{'httpd_can_network_connect':
          value => on,
          persistent => true,
      }
    }
}
