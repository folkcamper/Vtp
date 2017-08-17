#! /Skel/bin/perl
my $VERSION='2017-08-09.01-11-10.EDT';
my $VERSION = '2017-08-07.08-02-38.EDT';

# start recording a video file, of a specified window,
# or of a specified resolution, anchored top right.

use Cwd qw(cwd);
use Getopt::Std;
use Sort::Naturally qw(nsort);
use Pdt::SourceEnv qw(:all);
use X11::XWinInfo;
use X11::ScreenRes;
use Vtp::Vtprc;
use Forks::Super;
use Data::Dumper qw(Dumper);

use strict;

my $_DEBUG = 0;

my %OPTS;
getopts( 'p:w:r:e:dkh', \%OPTS );    # filename_prefix, windowid, resolution, kill, env,  help

### GET ENVIRONMENT

my $vtpfile = "$ENV{'HOME'}/.vtprc";
&sourceenv("$ENV{'HOME'}/.vtprc");    # make the environment current
&sourceenv("$ENV{'HOME'}/.pdtrc") if $ENV{'VTP_USE_PDT'};    # make the environment current
umask( $ENV{'PDT_UMASK'} ) if length( $ENV{'PDT_UMASK'} );

### DEVICES

my $sdm = $ENV{'SOUND_DEV_MIC'};                             #
die("microphone device undefined. Please set environment variable: SOUND_DEV_MIC\nHint: use asound -L and edit .bashrc or .usersetup\n") unless length($sdm);

### CREATE AN ENVIRONMENT TEMPLATE

my $rctemplate = Vtp::Vtprc->new();
$rctemplate->appendenv();

### HELP

&dohelp if ( defined $OPTS{'h'} );
my $aloo = length( $OPTS{'w'} ) + length( $OPTS{'r'} ) + length( $OPTS{'k'} );
$aloo = 1 if exists( $OPTS{'e'} );
$aloo = 1 if exists( $OPTS{'d'} );

&dohelp unless $aloo;

### CONTAINERS

my $windowid;     # windowid to identify the record target
my $geometry;     # X geometry string to identify the record target
my $videopid;     # pid of the ffmpeg instance recording the window
my $soundpid;     # pid of the notice sound
my $prefix;       # string designating prefix of the recorded file
my $writepath;    # fully qualified directory to write the video ile
my $writefn;      # the filename of the writable video file.

### MAIN

if ( defined( $OPTS{'k'} ) && length( $ENV{'VTP_VIDEOPID'} ) ) {    # kill stored pid

   system("xmessage $ENV{'VTP_VIDEOPID'} $ENV{'SOUND_STOPRECORD'}") if $_DEBUG;

   system("kill $ENV{'VTP_VIDEOPID'}");

   sleep 1;

   my $stopsound = $ENV{'SOUND_STOPRECORD'};
   $soundpid = fork { exec => "aplay $stopsound" } if ( length($stopsound) );

   # play a sound

   $rctemplate->append( 'vtp_videopid' => '' );    # empty the video pid

   # write the rc file

   singlequote( $rctemplate, 'vtp_videogeom', 'vtp_imagegeom' );
   &printrc($rctemplate);

   exit;

} elsif ( exists( $OPTS{'e'} ) ) {                 # record using environment settings

   $windowid = $OPTS{'e'} if ( length( $OPTS{'e'} ) );
   $geometry = $ENV{'VTP_VIDEOGEOM'};

   # if there is no geometry in the environment we assume that the
   # calling window is what we should record.

   unless ( length($geometry) ) {
      if ( length( $OPTS{'e'} ) ) {
         my $X = X11::XWinInfo->new( $OPTS{'e'} );
         $geometry = $X->xwingeom();
         $geometry = "\' $geometry \'";

         # $rctemplate->append( 'vtp_videogeom' => $geometry ) ; # but don't persist
         $rctemplate->append( 'vtp_videores' => '' );    # empty the video resolution
      } else {
         system("xmessage $OPTS{'e'}") if $_DEBUG;
         die("no resolution or windowid specified: $OPTS{'e'}");
      }
   }

} elsif ( length( $OPTS{'r'} ) ) {    # if a resolution is specified
   $OPTS{'r'} =~ tr/a-z/A-Z/;

   my $S = X11::ScreenRes->new();

   die("no resolution $OPTS{'r'} found") unless defined $S->{ $OPTS{'r'} };

   my $width  = $S->{ $OPTS{'r'} }->[ 0 ];
   my $height = $S->{ $OPTS{'r'} }->[ 1 ];
   my $X      = X11::XWinInfo->new();

   $geometry = $X->anchorgeom( $width, $height );
   $geometry = "\' $geometry \'";

   $rctemplate->append( 'vtp_videogeom' => $geometry );
   $rctemplate->append( 'vtp_videores'  => $OPTS{'r'} );    # empty the video resolution

} elsif ( length( $OPTS{'w'} ) ) {                          # record a specified windowid

   my $X = X11::XWinInfo->new($windowid);
   $geometry = $X->xwingeom();
   $geometry = "\' $geometry \'";

   $rctemplate->append( 'vtp_videogeom' => $geometry );
   $rctemplate->append( 'vtp_videores'  => $OPTS{'r'} );    # empty the video resolution

} elsif ( length( $OPTS{'d'} ) ) {                          # record the whole desktop

   my $X = X11::XWinInfo->newdesk();

   $geometry = $X->xwingeom();
   $geometry = "\' $geometry \'";

   $rctemplate->append( 'vtp_videogeom' => $geometry );
   $rctemplate->append( 'vtp_videores'  => '' );            # empty the video resolution

} else {
   &dohelp;
}

# now we assemble the filename and write it to
# the environment

$writepath = $ENV{'HOME'};
$writepath = pdtwritepath() if $ENV{'VTP_USE_PDT'};
$prefix    = setgetprefix();
$writefn   = makefn( $writepath, $prefix );
$rctemplate->append( 'vtp_videofile' => $writefn );

# NOTE: a great deal of troubleshooting went into using alsa as a source for ffmpeg instead
# of pulseaudio. Unfortunately the generic driver is not up to the task. We are able to get
# recording with alsa, but we either end up with an echo, or the sound quality goes to
# crap. If alsa ever gets fixed or replaced the command should be changed to sample
# directly from alsa. However, here we sample from pulseaudio instead because that
# is the only reliable way to get a clean mic tone.

my $startsound = $ENV{'SOUND_STARTRECORD'};
$soundpid = fork { exec => "aplay $startsound" } if ( length($startsound) );

$geometry =~ s/\'//g;    # dequote for the actual runtime command

my $vidcommand =
  "ffmpeg -thread_queue_size 512 -f pulse -ac 2 -i default -f x11grab $geometry -r 32 -acodec pcm_s16le -vcodec libx264 -preset ultrafast -crf 0 -y $writefn";
print $vidcommand ;

$videopid = fork { "exec" => "$vidcommand" };    # get arecord PID

$rctemplate->append( 'vtp_videopid' => $videopid );    # empty the video resolution
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

   return ( $ENV{'HOME'} ) if ( length( $ENV{'VTP_VIDEORES'} ) + length( $OPTS{'r'} ) ) < 1;

   my $r;    # The resolution name

   if ( length( $OPTS{'r'} ) ) {    # -r

      $r = $OPTS{'r'};
      my $S = X11::ScreenRes->new();
      unless ( exists $S->{$r} ) {
         warn("screenres $r not found in X11::ScreenRes");
         return ( $ENV{'HOME'} );
      }

   } else {                         # -e

      $r = $ENV{'VTP_VIDEORES'};
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

$rctemplate->append( 'vtp_videogeom' => $geometry );

sub setgetprefix {
   my $prefix;

   if ( length( $OPTS{'p'} ) ) {
      $prefix = $OPTS{'p'};
      $prefix =~ s/\.$//g;
      $prefix =~ s/^\.//g;
      $rctemplate->append( 'vtp_videoprefix' => $OPTS{'p'} );
   } elsif ( length( $ENV{'VTP_VIDEOPREFIX'} ) ) {
      $prefix = $ENV{'VTP_VIDEOPREFIX'};
      $rctemplate->append( 'vtp_videoprefix' => $ENV{'VTP_VIDEOPREFIX'} );
   } else {
      $prefix = 'video';
   }

   return $prefix;
}

sub makefn {    # assemble the filename
   my $path    = shift;
   my $prefix  = shift;
   my $isotime = `isotime`;
   chomp $isotime;
   my $extension = 'mkv';

   my $fn = $path . '/' . $prefix . '.' . $isotime . '.' . $extension;

   return $fn;
}

sub dohelp {

   print "-w <windowid> -p <video_filename_prefix> -r <resolution_name> -e (configure from environment)\n\n";
   exit;

}

