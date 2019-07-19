#!/usr/bin/perl
#########################################################################
#									# 
# This script checks for failed jobs in the last 24 hours in Netbackup.	#
# Creates and Excel spreadsheet and emails the report off.		#
# Can be used with multiple master servers.				#
#									#
# Copyright March 2009 Benjamin J Schmaus				#
#									#
#########################################################################
###### Many Modules Required ######
use strict;
use warnings;
use Socket;
use VMware::VIRuntime;
use VMware::VILib;
use VMware::VIM25Stub;
use Getopt::Long;
use Time::Local;
use POSIX qw(strftime);
use DateTime;
use Time::Local;
###### Variables to set ######
my $date = time();
my $yesterday = time() - ( 24 * 60 * 60 );
my $errorcodes = "/usr/openv/scripts/error_codes";
my @jobs="";my @failed="";my $lob="L&A";my $og="";
my ($stat,$datefixed,$starttime,$dow,$wod,$datum,$line,$dt,$class,$client,$j1,$j2,$j3,$j4,$j5,$j6,$j7,$output,@output,$start,$status,$master);
my (@ARRAY,$jobs,$jobid,$jobtype,$state,$sched,$server,$elapsed,$end,$kilobytes,@schedcaldayoweek,@schedtmp,@schedule,@schedwintmp,@schedwin);
my ($out,$windowl,$schedule2,$field2,$field1,@schedcalendar,@schedres,@schedpool,@schedrl,@schedfoe);
my ($help,$vcserver,$username,$password,$dc,$removesnapshot,$children,$snapshotname);
my $num="2";my $first = "0";my $last = "0";my $schd1 = "SCHED ";my $schd2 = "SCHED";my $counter = "0";my $hour = "0";my $minute = "0";my $second = "0";
my $arraycount = 0;my @gac = 0;
my $year = `date +%Y`;
my $month = `date +%m`;
my $day = `date +%d`;
my $rerun; my @rerunarray; my $rerunarray;my $rerunchk;

#### Edit the next line putting in the masters you want to poll #####
my @master = ("athena");
my $master2 = ("athena");

### Get all activity monitor jobs for all masters ###
foreach $master (@master) {
	@output = `/usr/openv/netbackup/bin/admincmd/bpdbjobs -report -M $master -gdm`;
	foreach $output (@output) {
		$jobs[++$#ARRAY] = $output;
	}
}
### Clear snaps if there are any  ###
print "Clearing snaps...\n";
system "/usr/openv/scripts/asnapper.pl -v asdmnesxvc2 -u nagios -p VMware2009 -d Fridley -sm VCB";

### Get only failed jobs in the last 24 hours and load into array ###
print "Checking schedules...\n";
foreach $jobs (@jobs) {
	($jobid,$jobtype,$state,$status,$class,$sched,$client,$server,$start,$elapsed,$end,$j1,$j2,$j3,$j4,$j5,$kilobytes,$j6,$j7) = split (',',$jobs);
	if (($class =~ /VMWARE/) && ($status eq "156") && ($start >= $yesterday) && ($start <= $date)) {
		getschedule();
		$rerun = "$jobid:$client:$class:$schedule2";
		$rerunchk = "0";
		foreach $rerunarray (@rerunarray) {
			if ($rerunarray =~ /$client/) { $rerunchk = "1"; 
				$rerunchk = "1";
			}
		}
		if ($rerunchk eq "0") {
			push (@rerunarray, $rerun);
		}
	}
}
print "Rerunning jobs...\n";
foreach $rerunarray (@rerunarray) {
	($jobid,$client,$class,$schedule2) = split (/:/,$rerunarray);
	system "/usr/openv/netbackup/bin/admincmd/bpdbjobs -delete $jobid -M $master2";
	system "/usr/openv/netbackup/bin/bpbackup -p $class -i -h $client -s $schedule2";
}


exit;

sub getschedule {
	$first = "0";my $last = "0";
	$schd1 = "SCHED ";my $schd2 = "SCHED";
	$counter = "0";
	$hour = "0";$minute = "0";$second = "0";
	$arraycount = 0;
	@gac = 0;
	$year = `date +%Y`;
	$month = `date +%m`;
	$day = `date +%d`;
	$counter = 0;
	scheddatetime2();
        $counter = 0;
        chomp($class);
        open DATA, "/usr/openv/netbackup/bin/admincmd/bpplsched $class -l|";
        while (<DATA>) {
                $line = $_;
                chomp($line);
                if ($line =~ /$schd1/ && $first eq "0") { schedfirst(); }
                if ($line =~ /$schd2/ && $first eq "1") { schedchecks(); }
        }
        close DATA;
       	for ($out = 0; $out < $counter; $out++) {
       		schedparseit();
        }
}

sub schedparseit {
        $field2 = ($dow*2);
        $field1 = ($dow*2)-1;
        @schedtmp = split(/[ \t]+/,$schedule[$out]);
        $schedule2 = $schedtmp[1];
        @schedwintmp = split(/[ \t]+/,$schedwin[$out]);
        $starttime = ($schedwintmp[$field1]/(60*60));
        $starttime =~ s/(^\d{1,}\.\d{2})(.*$)/$1/;
        $windowl = ($schedwintmp[$field2]/(60*60));
        $windowl =~s/(^\d{1,}\.\d{2})(.*$)/$1/;
}

sub scheddatetime2 {
        $dt = DateTime->new(year=>$year, month=>$month,day=>$day,hour=>$hour,minute=>$minute,second=>$second,nanosecond=>00,time_zone=>'America/Chicago',);
        $dow = $dt->day_of_week;                ##### 1-7 (Monday is 1) - also dow, wday
        $wod = $dt->weekday_of_month();         ##### 1-5 weeks
        if ($dow eq "7") { $dow = "1"; } else { $dow = $dow +1; }
        $datum = "$dow,$wod";
        chomp($datum);
}


sub schedfirst {
        $first = "1";
        $schedule[$counter] = "$line";
}

sub schedchecks {
        if ($line =~ /SCHEDCALENDAR/) {
                $schedcalendar[$counter] = "SCHEDCALENDAR enabled";
        }
        if ($line =~ /SCHEDCALDAYOWEEK/) {
                $schedcaldayoweek[$counter] = "$line";
        }
        if ($line =~ /SCHEDWIN/) {
                $schedwin[$counter] = "$line";
        }
        if ($line =~ /SCHEDRES/) {
                $schedres[$counter] = "$line";
        }
        if ($line =~ /SCHEDPOOL/) {
                $schedpool[$counter] = "$line";
        }
        if ($line =~ /SCHEDRL/) {
                $schedrl[$counter] = "$line";
        }
        if ($line =~ /SCHEDFOE/) {
                $schedfoe[$counter] = "$line";
                $first = "0";
                $counter = $counter+1;
        }
}
