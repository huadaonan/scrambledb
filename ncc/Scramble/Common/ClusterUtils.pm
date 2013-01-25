package Scramble::Common::ClusterUtils;
use strict;
use warnings FATAL => 'all';


sub delete_pid_if_exists($$) {
    my $pidfile = shift;
    my $ip      = shift;
    my $err     = "000000";

    if ( -e $pidfile ) {
        open PIDHANDLE, "$pidfile";
        my $localpid = <PIDHANDLE>;
        close PIDHANDLE;
        chomp $localpid;
        $err =
          worker_node_command( "tail -f /dev/null --pid " . $localpid, $ip );
    }
    return $err;
}


sub is_ip_from_status_present($$) {
  my $status =shift;
  my $ip =shift;
  foreach  my $instance (  @{ $status->{instances_status}->{instances}} ) {
    foreach my $key (keys %$instance) {
      if((defined ($instance->{$key}->{ip}) ? $instance->{$key}->{ip}:"" ) eq $ip) {
        return 1;
      }
    }
   }
  return 0; 
}

sub is_ip_from_status_running($$) {
  my $status =shift;
  my $ip =shift;
     
  foreach  my $instance (  @{ $status->{instances_status}->{instances}} ) {
    foreach my $key (keys %$instance) {
       if((defined ($instance->{$key}->{ip}) ? $instance->{$key}->{ip}:"" ) eq $ip) {
      
        if($instance->{$key}->{state} eq "running" ) {
            return 1;
        }
      }    
    }
   }
  return 0; 
}



sub is_ip_localhost($) {
    
    my $testIP = shift;
    
    my %IPs;
    my $interface;

    foreach (qx{ (LC_ALL=C /sbin/ifconfig -a 2>&1) }) {
        $interface = $1 if /^(\S+?):?\s/;
        next unless defined $interface;
        $IPs{$interface}->{STATE} = uc($1) if /\b(up|down)\b/i;
        $IPs{$interface}->{STATE} =defined( $IPs{$interface}->{STATE}) ?  $IPs{$interface}->{STATE} : "na";
        $IPs{$interface}->{IP}    = $1     if /inet\D+(\d+\.\d+\.\d+\.\d+)/i; 
        $IPs{$interface}->{IP} =defined( $IPs{$interface}->{IP}) ?  $IPs{$interface}->{IP} : "na";
    }
   

    foreach my $key ( sort keys %IPs ) {
        if ( $IPs{$key}->{IP} eq $testIP ) {
            return 1;
        }
    }
    return 0;
}

sub get_instance_id_from_status_ip($$){
my $status =shift;
 my $ip =shift;
  foreach  my $instance (  @{ $status->{instances_status}->{instances}} ) {
    foreach my $key (keys %$instance) {
     if((defined ($instance->{$key}->{ip}) ? $instance->{$key}->{ip}:"" ) eq $ip) {
            return $instance->{$key}->{id};
       }     
    }
   }
  return 0; 
}

sub get_all_slaves($) {
    my $config =shift;
    my $host_info;
    my $err = "000000";
    my @slaves;
    my $cloud_name = get_active_cloud_name($config);
  
    foreach my $host ( keys( %{ $config->{db} } ) ) {
        $host_info = $config->{db}->{default};
        $host_info = $config->{db}->{$host};
        if ( $host_info->{status} eq "slave" && $host_info->{cloud} eq $cloud_name ) {
            push( @slaves, $host_info->{ip} . ":" . $host_info->{mysql_port} );
        }
    }

    return join( ',', @slaves );
}

sub get_all_masters($) {
    
    my $config =shift;
    my $host_info;
    my $err = "000000";
    my @masters;
     my $cloud_name = get_active_cloud_name($config);
    foreach my $host ( keys( %{ $config->{db} } ) ) {
        $host_info = $config->{db}->{default};
        $host_info = $config->{db}->{$host};
        if ( $host_info->{status} eq "master" && $host_info->{cloud} eq $cloud_name  ) {
            push( @masters, $host_info->{ip} . ":" . $host_info->{mysql_port} );
        }
    }
    return join( ',', @masters );
}

sub get_all_memcaches($) {
    my $config =shift;
    my $host_info;
    my $err = "000000";
    my @memcaches;
    my $cloud_name = get_active_cloud_name($config);
    foreach my $host ( keys( %{ $config->{db} } ) ) {
        $host_info = $config->{db}->{default};
        $host_info = $config->{db}->{$host};
        if ( $host_info->{mode} eq "memcache" && $host_info->{cloud} eq $cloud_name ) {
            push( @memcaches,
                $host_info->{ip} . ":" . $host_info->{mysql_port} );
        }
    }
    return join( ',', @memcaches );
}

sub get_all_sercive_ips($) {
    my $config =shift;
    my $host_info;
    my $err = "000000";
    my @ips;
    my $cloud_name = get_active_cloud_name($config);
    foreach my $host ( keys( %{ $config->{db} } ) ) {
        $host_info = $config->{db}->{default};
        $host_info = $config->{db}->{$host};
          if ( $host_info->{cloud} eq $cloud_name  ) { push( @ips, $host_info->{ip} )};
    }
    foreach my $host ( keys( %{ $config->{nosql} } ) ) {
        $host_info = $config->{nosql}->{default};
        $host_info = $config->{nosql}->{$host};
        if ( $host_info->{cloud} eq $cloud_name  ) { push( @ips, $host_info->{ip} );}
    }
    foreach my $host ( keys( %{ $config->{proxy} } ) ) {
        $host_info = $config->{proxy}->{default};
        $host_info = $config->{proxy}->{$host};
        if ( $host_info->{cloud} eq $cloud_name  ) { push( @ips, $host_info->{ip} );}
    }
     foreach my $host ( keys( %{ $config->{lb} } ) ) {
        $host_info = $config->{lb}->{default};
        $host_info = $config->{lb}->{$host};
        if ( $host_info->{cloud} eq $cloud_name  ) { push( @ips, $host_info->{ip} );}
    }

    return uniq(@ips);
}




sub get_local_instances_status($) {
    my $config =shift;
    my @ips=get_all_sercive_ips($config);
    my @interfaces;
    my $i=0;
    my $host_info;
    
    foreach my $ip ( @ips)  {
        push @interfaces, {"instance". $i=>  {
            id     => "instance". $i,
            ip       => $ip,
            state       => "running"
           }     
        };

     $i++;    
    }
    my $json       = new JSON;
     my $json_instances_status =  $json->allow_blessed->convert_blessed->encode(\@interfaces);
   
   return $json_instances_status ; 
}


sub get_active_cloud($) {
    my $config =shift;
    my $host_info;
    foreach my $host ( keys( %{ $config->{cloud} } ) ) {
        $host_info = $config->{cloud}->{default};
        $host_info = $config->{cloud}->{$host};
        if ( $host_info->{status} eq "master" ) {
            return $host_info;
        }
    }
   return 0; 
}

sub get_active_cloud_name($) {
    my $config =shift;
    my $host_info;
    foreach my $host ( keys( %{ $config->{cloud} } ) ) {
        $host_info = $config->{cloud}->{default};
        $host_info = $config->{cloud}->{$host};
        if ( $host_info->{status} eq "master" ) {
            return $host;
        }
    }
   return 0; 
}

sub get_active_monitor($) {
    my $config =shift;
    my $host_info;
     my $cloud_name = get_active_cloud_name($config);
    foreach my $host ( keys( %{ $config->{monitor} } ) ) {
        $host_info = $config->{monitor}->{default};
        $host_info = $config->{monitor}->{$host};
      if ( $host_info->{cloud} eq $cloud_name  ) {
      # $host_info->{status} eq "master" 
            return $host_info;
        }
    }
   return 0; 
}

sub get_active_db($) {
    my $config =shift;
    my $host_info;
    my $cloud_name = get_active_cloud_name($config);
    foreach my $host ( keys( %{ $config->{db} } ) ) {
        $host_info = $config->{db}->{default};
        $host_info = $config->{db}->{$host};
        if ( $host_info->{status} eq "master"  && $host_info->{cloud} eq $cloud_name ) {
            return $host_info;
        }
    }
   return 0; 
}


sub get_active_memcache($) {
    my $config =shift;
    my $nosql_info; 
      my $cloud_name = get_active_cloud_name($config);
    foreach my $nosql (keys(%{$config->{nosql}})) {
        $nosql_info = $config->{nosql}->{default};
        $nosql_info = $config->{nosql}->{$nosql};
        if  ( $nosql_info->{status} eq "master" &&  $nosql_info->{mode} eq "memcache"  && $nosql_info->{cloud} eq $cloud_name){
           return $nosql_info;
        }
    }    
    return 0;
}

sub get_active_lb($) {
    my $config =shift;
    my $host_info; 
    my $cloud_name = get_active_cloud_name($config);
    foreach my $bench ( keys( %{ $config->{lb} } ) ) {

       $host_info = $config->{lb}->{default};
        $host_info = $config->{lb}->{$bench};
        if ( $host_info->{mode} eq "keepalived" && $host_info->{status} eq "master" && $host_info->{cloud} eq $cloud_name) {
            return $host_info;
        }
    }
    return 0;
}

sub get_active_lb_name($) {
    my $config =shift;
    my $host_info; 
    my $cloud_name = get_active_cloud_name($config);
    foreach my $lb ( keys( %{ $config->{lb} } ) ) {

       $host_info = $config->{lb}->{default};
        $host_info = $config->{lb}->{$lb};
        if ( $host_info->{mode} eq "keepalived" && $host_info->{status} eq "master" && $host_info->{cloud} eq $cloud_name) {
            return $lb;
        }
    }
    return 0;
}

sub get_lb_name_from_ip($$) {
    my $config =shift; 
    my $ip = shift;
    my $host_info; 
    my $cloud_name = get_active_cloud_name($config);
    foreach my $lb ( keys( %{ $config->{lb} } ) ) {

       $host_info = $config->{lb}->{default};
        $host_info = $config->{lb}->{$lb};
        if ( $host_info->{mode} eq "keepalived" && $host_info->{ip} eq $ip && $host_info->{cloud} eq $cloud_name) {
            return $lb;
        }
    }
    return 0;
}

sub get_lb_peer_name_from_ip($$) {
    my $config =shift;
    my $ip = shift;
    my $host_info; 
    my $cloud_name = get_active_cloud_name($config);
    foreach my $lb ( keys( %{ $config->{lb} } ) ) {

       $host_info = $config->{lb}->{default};
        $host_info = $config->{lb}->{$lb};
        if ( $host_info->{mode} eq "keepalived" && $host_info->{ip} eq $ip && $host_info->{cloud} eq $cloud_name) {
            return $host_info->{peer};
        }
    }
    return 0;
}


sub get_active_master_db_name($) {
    my $config =shift;
    my $host_info;
    my $cloud_name = get_active_cloud_name($config);
    foreach my $host ( keys( %{ $config->{db} } ) ) {
        $host_info = $config->{db}->{default};
        $host_info = $config->{db}->{$host};
        if ( $host_info->{status} eq "master"  && $host_info->{cloud} eq $cloud_name) {
            return $host;
        }
    }
   return 0; 
}

sub get_my_ip_from_config($)    {

  my $config =shift;
  my @ips = get_all_sercive_ips($config);
    foreach (@ips) {
        if ( is_ip_localhost($_) == 1 ) {
           return $_;
       }
    } 
    return 0;
}
sub get_all_ip_from_status($) {
  my $status =shift;
   my @serviceips;  
  foreach  my $service (  @{ $status->{services_status}->{services}} ) {
    foreach my $key (keys %$service) {
     push (@serviceips,$service->{$key}->{ip} );
   }
   }

  return @serviceips; 
}

sub get_source_ip_from_status($) {
  my $status =shift;
   my @serviceips;  
   foreach  my $interface (  @{ $status->{host}->{interfaces}} ) {
    foreach my $attr (keys %$interface) {
          foreach  my $service (  @{ $status->{services_status}->{services}} ) {
               foreach my $key (keys %$service) {
                    if ($service->{$key}->{ip} eq $interface->{$attr}->{IP} ){
                        return $interface->{$attr}->{IP};
                    }
          } 
        }
         
      }
    }  
  return "0.0.0.0"; 
}

sub get_status_diff($$) {
  my $previous_status =shift;
  my $status_r =shift;
  
  my $i=0;
  my @diff;
   
   
  foreach  my $service (  @{ ${$status_r}->{services_status}->{services}} ) {
   foreach my $key (keys %$service) {
      # service name may change or service removed  
      if (  defined($previous_status->{services_status}->{services}[$i]->{$key}->{state}) )
      { 
           
      print STDERR $key . "\n";    
      if ( $service->{$key}->{state} ne $previous_status->{services_status}->{services}[$i]->{$key}->{state}
            || $service->{$key}->{code} ne $previous_status->{services_status}->{services}[$i]->{$key}->{code}
         )    
      {
            print STDERR "trigger";
          push @diff, {
         name     => $key ,
         type     => "services",
         ip    => $service->{$key}->{ip} ,
         state    => $service->{$key}->{state} ,
         code     => $service->{$key}->{code} , 
         previous_state =>$previous_status->{services_status}->{services}[$i]->{$key}->{state},
         previous_code =>$previous_status->{services_status}->{services}[$i]->{$key}->{code}
        };  
        
       }
       
     }
     }
      
   $i++;
  }
   $i=0;
   foreach  my $instance (  @{ ${$status_r}->{instances_status}->{instances}} ) {
     foreach my $attr (keys %$instance) {
       my $skip=0; 
       print STDERR "ici test ssh\n"; 
       if ( (defined ($instance->{$attr}->{state}) ? $instance->{$attr}->{state}:"") ne 
          (defined ($previous_status->{instances_status}->{instances}[$i]->{$attr}->{state}) ? $previous_status->{instances_status}->{instances}[$i]->{$attr}->{state} :"")

        )    
       {
           
            if ((defined($instance->{$attr}->{state}) ? $instance->{$attr}->{state} : "" ) eq "running"){
             if( instance_check_ssh($instance->{$attr}->{ip}) ==0 ) {
                  print STDERR "skipping because ssh failed\n";
                  ${$status_r}->{instances_status}->{instances}[$i]->{$attr}->{state}="pending";
                     $skip=1;  
               
`   `         } 

         } 
         if ($skip==0 )   {
           print STDERR "trigger";
          
           push @diff, {
            name     => $instance->{$attr}->{id} ,
            type     => "instances",
            ip       => defined($instance->{$attr}->{ip}) ?  $instance->{$attr}->{ip} : "",
            state    => defined($instance->{$attr}->{state} ) ? $instance->{$attr}->{state} : "" ,
            code     => "0" , 
            previous_state =>$previous_status->{instances_status}->{instances}[$i]->{$attr}->{state},
            previous_code =>0
          };  
        }

       }
       }
       $i++;
     }  
     my $json       = new JSON;
     my $json_status_diff = '{"events":' . $json->allow_blessed->convert_blessed->encode(\@diff).'}';
     print STDERR   $json_status_diff . "\n";
     return $json_status_diff;
}

sub get_table_name_from_sql($) {
    my $lquery = shift;
    my @tokens = tokenize_sql($lquery);
    my $next_i = 1;
    for my $token (@tokens) {
        if ( lc $token eq "table" ) {
            return $tokens[$next_i];
        }
        $next_i++;
    }
}

sub get_90th_per($$)  {
    my $self = shift;
    my $index = shift;
    
    my @data = @_;
    $index= defined ($index) ? $index : 0;
    use POSIX qw(ceil floor);
    my $result;
    my $floor = floor($index);
    my $ceil = ceil($index);
    if ($floor == $ceil) {
        $result = $data[$index];
    } else {
        if ($data[$ceil]) {
            $result = ($data[$floor] + $data[$ceil]) / 2;
        } else {
            $result = $data[$floor];
        }
    }
    return $result;
}

sub RPad($$$) {

    my $str = shift;
    my $len = shift;
    my $chr = shift;
    $chr = " " unless ( defined($chr) );
    return substr( $str . ( $chr x $len ), 0, $len );
}    



sub replace_config_line($$$) {
    my $file   = shift;
    my $strin  = shift;
    my $strout = shift;

    open my $in,  '<', $file       or die "Can't read old file: $!";
    open my $out, '>', "$file.new" or die "Can't write new file: $!";

    while (<$in>) {
        s/^$strin(.*)$/$strout/gi;
        print $out $_;
    }

    close $out;
    system("rm -f $file.old");
    system("mv $file $file.old");
    system("mv $file.new $file");
    system("chmod 660 $file");
}

sub uniq {
    my %seen;
    return grep { !$seen{$_}++ } @_;
}

sub tokenize_sql($) {
    my $query = shift;
    my $re    = qr{
		(
			(?:--|\#)[\ \t\S]*      # single line comments
			|
			(?:<>|<=>|>=|<=|==|=|!=|!|<<|>>|<|>|\|\||\||&&|&|-|\+|\*(?!/)|/(?!\*)|\%|~|\^|\?)
									# operators and tests
			|
			[\[\]\(\),;.]            # punctuation (parenthesis, comma)
			|
			\'\'(?!\')              # empty single quoted string
			|
			\"\"(?!\"")             # empty double quoted string
			|
			".*?(?:(?:""){1,}"|(?<!["\\])"(?!")|\\"{2})
									# anything inside double quotes, ungreedy
			|
			`.*?(?:(?:``){1,}`|(?<![`\\])`(?!`)|\\`{2})
									# anything inside backticks quotes, ungreedy
			|
			'.*?(?:(?:''){1,}'|(?<!['\\])'(?!')|\\'{2})
									# anything inside single quotes, ungreedy.
			|
			/\*[\ \t\n\S]*?\*/      # C style comments
			|
			(?:[\w:@]+(?:\.(?:\w+|\*)?)*)
									# words, standard named placeholders, db.table.*, db.*
			|
			\n                      # newline
			|
			[\t\ ]+                 # any kind of white spaces
		)
	   }smx;
    my @ltokens = $query =~ m{$re}smxg;

    @ltokens = grep( !/^[\s\n\r]*$/, @ltokens );

    return wantarray ? @ltokens : \@ltokens;
}

1;