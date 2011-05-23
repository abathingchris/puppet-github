define github::mirror (
  $ensure
) {

  $user = $github::settings::user
  $group = $github::settings::group
  $basedir = $github::settings::basedir

  $github_user = regsubst($name, '^(.*?)/.*$', '\1')
  $repo_name = regsubst($name, '^.*/(.*$)', '\1')
  $repo = "$basedir/$github_user/$repo_name.git"

  case $ensure {
    present: {
      if ! defined(File["$basedir/$github_user"]) {
        file { "$basedir/$github_user":
          ensure  => directory,
          owner   => $user,
          group   => $group,
        }
      }

      vcsrepo { "$repo":
        ensure    => bare,
        provider  => "git",
        source    => "https://github.com/$github_user/$repo_name.git",
        require   => File["$basedir/$github_user"],
      }

      file { "$repo":
        ensure  => directory,
        owner   => $user,
        group   => $group,
        recurse => true,
        backup  => false,
        require => Vcsrepo[$repo],
      }

      exec { "git-export-$github_user-$repo_name":
        path      => [ "/bin", "/usr/bin" ],
        command   => "touch $repo/git-daemon-export-ok",
        user      => $user,
        group     => $group,
        logoutput => true,
        require   => [Vcsrepo[$repo], File[$repo]]
      }

      if ! defined(Exec["git-daemon"]) {
        exec { "git-daemon":
          path      => [ "/bin", "/usr/bin" ],
          user      => $user,
          group     => $group,
          command   => "git daemon --detach --reuseaddr --base-path=$basedir --base-path-relaxed --pid-file=$basedir/.git-daemon.pid $basedir",
          logoutput => true,
        }
      }
    }
    absent: {
      file { "$repo":
        force => true,
        ensure => absent;
      }
    }
    default: {
      fail("Invalid ensure value $ensure on github::mirror $name")
    }
  }
}