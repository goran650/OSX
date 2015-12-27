#!/usr/bin/perl

use strict;
use warnings;

sub printMemUsage($)
{
    my ($numTop) = @_;

    my $psCommand = '/bin/ps axmc -o rss,comm';
    my $count = 0;
    my $totalRssMB = 0;
    open(PS, "$psCommand |") or die "Failed to run '$psCommand': $!\n";
    while(<PS>)
    {
        if (/^\s*(\d+)\s+(.*)$/)
        {
            my $rss = $1;
            my $comm = $2;
            my $rssMB = $rss / 1024;
            $totalRssMB += $rssMB;
            if ($count++ < $numTop)
            {
                printf("%5.1f MB\t%s\n", $rssMB, $comm);
            }
        }
    }
    close(PS);
    printf ("total: %6.1f MB\n", $totalRssMB);
}

sub printDate()
{
    my $date = localtime(time());
    print "$date\n";
}

sub getVmStats()
{
    my %vmStats = ();
    my $vmStatsCommand = '/usr/bin/vm_stat';
    open(VMSTATS, "$vmStatsCommand |")
            or die "Failed to run '$vmStatsCommand': $!\n";
    while(<VMSTATS>)
    {
        if (/^\s*([^:]+):\s*(\d+)\.$/)
        {
            my $name = $1;
            my $value = $2;
            $vmStats{$name} = $value;
        }
    }
    close(VMSTATS);
    return \%vmStats;
}

INIT
{
    my $prevNumPageouts = -1;
    sub printNumPageouts()
    {
        my $vmStatsRef = getVmStats();
        my $numPageouts = $$vmStatsRef{'Pageouts'};
        if ($prevNumPageouts < 0)
        {
            print "pageouts: $numPageouts\n";
        }
        else
        {
            my $delta = $numPageouts - $prevNumPageouts;
            print "pageouts: $numPageouts  delta: $delta\n";
        }
        $prevNumPageouts = $numPageouts;
    }
}

sub printSwapInfo()
{
    system('/usr/sbin/sysctl vm.swapusage');
}

sub usageError($)
{
    my ($msg) = @_;

    print "Usage: $0 [numTop [loopDelay]]\n";
    die "$msg\n";
}


MAIN:
{
    my $numTop = 10;     # number of processes to show memory usage for
    my $loopDelay = 60; # number of seconds to sleep between iterations

    if (@ARGV)
    {
        $numTop = shift @ARGV;
        usageError("numTop must be positive integer")
            unless $numTop =~ /^\d+$/ and $numTop > 0;
    }
    if (@ARGV)
    {
        $loopDelay = shift @ARGV;
        usageError("loopDelay must be positive integer")
            unless $loopDelay =~ /^\d+$/ and $loopDelay > 0;
    }
    usageError("Too many arguments") if @ARGV;

    while(1)
    {
        printDate();
        printMemUsage($numTop);
        printNumPageouts();
        printSwapInfo();
        print "---------------------------------------------------------\n";
        sleep($loopDelay);
    }
}
