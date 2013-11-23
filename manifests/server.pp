# == Class zookeeper::server
# Configures a zookeeper server.
# This requires that zookeeper is installed
# And that the current nodes fqdn is an entry in the
# $::zookeeper::hosts array.
#
# == Parameters
# $jmx_port            - JMX port.    Set this to false if you don't want to expose JMX.
#
# $cleanup_count       - If this is > 0, this installs a cron to cleanup transaction
#                        and snapshot logs.  zkCleanup.sh - $cleanup_count will be run daily.
#                        Default: 10
#
class zookeeper::server(
    $jmx_port         = $::zookeeper::defaults::jmx_port,
    $cleanup_count    = $::zookeeper::defaults::cleanup_count,
    $cleanup_script   = $::zookeeper::defaults::cleanup_script,
    $default_template = $::zookeeper::defaults::default_template,
    $log4j_template   = $::zookeeper::defaults::log4j_template
)
{
    # need zookeeper common package and config.
    Class['zookeeper'] -> Class['zookeeper::server']

    # # Install zookeeper server package
    # package { 'zookeeperd':
    #     ensure    => $::zookeeper::version,
    # }

    file { '/etc/default/zookeeper':
        content => template($default_template),
        require => Package['zookeeper'],
    }

    file { "${::zookeeper::conf_dir}/log4j.properties":
        content => template($log4j_template),
        require => Package['zookeeper'],
    }

    file { $::zookeeper::data_dir:
        ensure => 'directory',
        owner  => 'zookeeper',
        group  => 'zookeeper',
        mode   => '0755',
    }

    # Get this host's $myid from the $fqdn in the $zookeeper_hosts hash.
    $myid = $::zookeeper::hosts[$::fqdn]
    file { "${::zookeeper::conf_dir}/myid":
        content => $myid,
    }
    file { "${::zookeeper::data_dir}/myid":
        ensure  => 'link',
        target  => "${::zookeeper::conf_dir}/myid",
    }

    service { 'zookeeper':
        ensure     => running,
        require    => [
            Package['zookeeper'],
            File[ $::zookeeper::data_dir],
            File["${::zookeeper::data_dir}/myid"],
        ],
        hasrestart => true,
        hasstatus  => true,
        subscribe  => [
            File["${::zookeeper::conf_dir}/zoo.cfg"],
            File["${::zookeeper::conf_dir}/myid"],
            File["${::zookeeper::conf_dir}/log4j.properties"],
        ],
    }

    cron { 'zookeeper-cleanup':
        command => "${cleanup_script} -n ${cleanup_count}",
        hour    => 0,
        user    => 'zookeeper',
        require => Service['zookeeper'],
    }

    # if !$cleanup_count, then ensure this cron is absent.
    if (!$cleanup_count or $cleanup_count <= 0) {
        Cron['zookeeper-cleanup'] { ensure => 'absent' }
    }
}