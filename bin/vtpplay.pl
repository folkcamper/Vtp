#! /Skel/bin/perl
my $VERSION='2017-08-08.02-04-06.EDT';
use Getopt::Std;
use Pdt::SourceEnv qw(:all);

use strict;

my $_DEBUG = 0;

my %OPTS;
getopts( 'vaih', \%OPTS );    # filename_prefix, windowid, resolution, kill, env,  help

### GET ENVIRONMENT

my $vtpfile = "$ENV{'HOME'}/.vtprc";
&sourceenv("$ENV{'HOME'}/.vtprc");    # make the environment current

if ( exists $OPTS{'v'} ) {
   exec("mplayer $ENV{'VTP_VIDEOFILE'}");
} elsif ( exists $OPTS{'a'} ) {
   exec("mplayer $ENV{'VTP_AUDIOFILE'}");
} elsif ( exists $OPTS{'i'} ) {
   exec("qiv $ENV{'VTP_IMAGEFILE'}");
}

sub help {
   print "-v play last recorded video\n";
   print "-a play last recorded audio\n";
   print "-i view last recorded screen capture\n";
}

