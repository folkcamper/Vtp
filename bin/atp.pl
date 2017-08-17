#! /Skel/bin/perl

# start recording a audio file, of a specified window,
# or of a specified resolution, anchored top right.

use Getopt::Std;
use Pdt::SourceEnv qw(:all);
use Vtp::Vtprc;
use Forks::Super;
use Data::Dumper qw(Dumper);

use strict;

my $_DEBUG = 0;

my %OPTS;
getopts( 'p:e:kh', \%OPTS );    # filename_prefix, windowid, resolution, kill, env, help

### GET ENVIRONMENT

my $vtpfile = "$ENV{'HOME'}/.vtprc";
&sourceenv("$ENV{'HOME'}/.vtprc"); # make the environment current
&sourceenv("$ENV{'HOME'}/.pdtrc") if $ENV{'VTP_USE_PDT'}; # make the environment current
umask( $ENV{'PDT_UMASK'} ) if length( $ENV{'PDT_UMASK'} );

### DEVICES

my $sdm = $ENV{'SOUND_DEV_MIC'};                             #

die("microphone device undefined. Please set environment variable: SOUND_DEV_MIC\nHint: use asound -L and edit .bashrc or .usersetup\n") unless length($sdm);

### CREATE AN ENVIRONMENT TEMPLATE

my $rctemplate = Vtp::Vtprc->new();
$rctemplate->appendenv();

### HELP

my $aloo ; 
&dohelp if ( defined $OPTS{'h'} );
$aloo = 1 if exists( $OPTS{'e'} );
$aloo = 1 if exists( $OPTS{'p'} );
$aloo = 1 if exists( $OPTS{'k'} );
&dohelp unless $aloo;

### CONTAINERS

my $soundpid;     # pid of the notice sound
my $audiopid;     # pid of the recording
my $prefix;       # string designating prefix of the recorded file
my $writepath;    # fully qualified directory to write the audio ile
my $writefn;      # the filename of the writable audio file.

### MAIN

if ( defined( $OPTS{'k'} ) && length( $ENV{'VTP_AUDIOPID'} ) ) {    # kill stored pid

   system("xmessage $ENV{'VTP_AUDPID'} $ENV{'SOUND_STOPRECORD'}") if $_DEBUG;

   system("kill $ENV{'VTP_AUDIOPID'}");

   sleep 1;

   my $stopsound = $ENV{'SOUND_STOPRECORD'};
   $soundpid = fork { exec => "aplay $stopsound" } if ( length($stopsound) );

   # play a sound

   $rctemplate->append( 'vtp_audiopid' => '' );    # empty the audio pid

   # write the rc file

   singlequote( $rctemplate, 'vtp_audiogeom', 'vtp_imagegeom' );
   &printrc($rctemplate);

   exit;

} elsif ( exists( $OPTS{'p'} ) ) {                 # record using environment settings
   $rctemplate->append( 'vtp_audioprefix' => $OPTS{'p'} );    # empty the audio pid
}

# now we assemble the filename and write it to
# the environment

$writepath = $ENV{'HOME'};
$writepath = pdtwritepath() if $ENV{'VTP_USE_PDT'};
$prefix    = setgetprefix();
$writefn   = makefn( $writepath, $prefix );
$rctemplate->append( 'vtp_audiofile' => $writefn );

# NOTE: a great deal of troubleshooting went into using alsa as a source for ffmpeg instead
# of pulseaudio. Unfortunately the generic driver is not up to the task. We are able to get
# recording with alsa, but we either end up with an echo, or the sound quality goes to
# crap. If alsa ever gets fixed or replaced, the top line might be useful, but for now
# we are using the bottom one, to allow pulse to clean up the microphone.

my $startsound = $ENV{'SOUND_STARTRECORD'};
$soundpid = fork { exec => "aplay $startsound" } if ( length($startsound) );

my $audcommand =
  "ffmpeg -thread_queue_size 512 -f pulse -ac 2 -i default -acodec pcm_s16le -preset ultrafast -y $writefn";

  # "ffmpeg -thread_queue_size 512 -f pulse -ac 2 -i default -acodec pcm_s16le -preset ultrafast -crf 0 -y $writefn";

print $audcommand ;

$audiopid = fork { "exec" => "$audcommand" };    # get arecord PID

$rctemplate->append( 'vtp_audiopid' => $audiopid );    # empty the audio resolution
singlequote( $rctemplate, 'vtp_videogeom', 'vtp_imagegeom' );

&printrc($rctemplate);

sub printrc {                                          # actually do the printing.
   my $rctemplate = shift;
   open( VTP, ">$vtpfile" );
   print VTP $rctemplate->output();
   close(VTP);
}

###

# we must have the actual resolution bits, and a directory
# handle named after the resolution, if the user is going
# to use named resolutions. pickwritepath returns either
# the correct directory to place the file, or $HOME.

sub pdtwritepath {

   # If we are using -e the environment variable will be set, if we are using
   # -r the option value will be set. If neither, we are probably using -w which
   # cannot vector.

   return ( $ENV{'HOME'} ) if ( length( $ENV{'VTP_AUDIORES'} ) + length( $OPTS{'r'} ) ) < 1;

   my $r;    # The resolution name

   if ( length( $OPTS{'r'} ) ) {    # -r

      $r = $OPTS{'r'};
      my $S = X11::ScreenRes->new();
      unless ( exists $S->{$r} ) {
         warn("screenres $r not found in X11::ScreenRes");
         return ( $ENV{'HOME'} );
      }

   } else {                         # -e

      $r = $ENV{'VTP_AUDIORES'};
      my $S = X11::ScreenRes->new();
      unless ( exists $S->{$r} ) {
         warn("screenres $r not found in X11::ScreenRes");
         return ( $ENV{'HOME'} );
      }

   }

   $writepath = $ENV{'PDT_ROOT'} . '/' . $ENV{'PDT_ACTIVE'} . '/' . "Video" . '/' . $r;

   unless ( -d $writepath ) {
      warn("pdtpath $writepath not found.");
      return ( $ENV{'HOME'} );
   }

   return ($writepath);
}

sub setgetprefix {
   my $prefix;

   if ( length( $OPTS{'p'} ) ) {
      $prefix = $OPTS{'p'};
      $prefix =~ s/\.$//g;
      $prefix =~ s/^\.//g;
      $rctemplate->append( 'vtp_audioprefix' => $OPTS{'p'} );
   } elsif ( length( $ENV{'VTP_AUDIOPREFIX'} ) ) {
      $prefix = $ENV{'VTP_AUDIOPREFIX'};
      $rctemplate->append( 'vtp_audioprefix' => $ENV{'VTP_AUDIOPREFIX'} );
   } else {
      $prefix = 'audio';
   }

   return $prefix;
}

sub makefn {    # assemble the filename
   my $path    = shift;
   my $prefix  = shift;
   my $isotime = `isotime`;
   chomp $isotime;
   my $extension = 'wav';

   my $fn = $path . '/' . $prefix . '.' . $isotime . '.' . $extension;

   return $fn;
}

sub dohelp {

   print "-p <audio_filename_prefix> -e (configure from environment)\n\n";
   exit;

}

