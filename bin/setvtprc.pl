#! /Skel/bin/perl
my $VERSION='2017-08-08.11-36-14.EDT';

# setvtprc, set prefered recording geometry on X11 based
# systems.

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

### DEFAULTS

my %OPTS;
getopts( 'w:r:p:fdeih', \%OPTS );    # windowid, resolution, prefix, float, desktop (Root window), initialize, help, VIDEOPID AUDIOPID, IMAGEPID

my $vtpfile = "$ENV{'HOME'}/.vtprc";

my $aloo = length( $OPTS{'w'} ) + length( $OPTS{'r'} ) + length( $OPTS{'d'} ) + length( $OPTS{'i'} ) + length( $OPTS{'p'} );
$aloo++ if ( defined $OPTS{'e'} );
$aloo++ if ( defined $OPTS{'f'} );

&dohelp if ( defined $OPTS{'h'} );
&dohelp unless $aloo;

my $geometry;                        # container for our geometry

### LOAD ENVIRONMENT

&sourceenv($vtpfile);                # dump the rc file into our environment.
my $rctemplate = Vtp::Vtprc->new();  # make a replacement rc file
$rctemplate->appendenv() unless length( $OPTS{i} );    # dump our environment into it (autorecasing)

if ( $OPTS{'d'} ) {                                    # Root Window

   my $X = X11::XWinInfo->newdesk();

   $geometry = $X->xwingeom();
   $geometry = "\' $geometry \'";

   $rctemplate->append( 'vtp_videogeom' => $geometry );
   $rctemplate->append( 'vtp_videores'  => '' );          # empty the video resolution

} elsif ( length( $OPTS{'r'} ) ) {                        # by resolution

   $OPTS{'r'} =~ tr/a-z/A-Z/;

   my $S = X11::ScreenRes->new();

   unless ( defined( $S->{ $OPTS{'r'} } ) ) {
      die("$OPTS{'r'} is not currently listed in X11 ScreenSes");
   }

   my $width  = $S->{ $OPTS{'r'} }->[ 0 ];
   my $height = $S->{ $OPTS{'r'} }->[ 1 ];

   my $X = X11::XWinInfo->new();

   $geometry = $X->anchorgeom( $width, $height );
   $geometry = "\' $geometry \'";

   # here we update our intended screen geometry

   $rctemplate->append( 'vtp_videogeom' => $geometry );
   $rctemplate->append( 'vtp_videores'  => $OPTS{'r'} );

   # warn $geometry if $_DEBUG ;

} elsif ( length( $OPTS{'w'} ) ) {    # by windowid

   my $X = X11::XWinInfo->new( $OPTS{'w'} );

   $geometry = $X->xwingeom();
   $geometry = "\' $geometry \'";

   $rctemplate->append( 'vtp_videogeom' => $geometry );
   $rctemplate->append( 'vtp_videores'  => '' );          # empty the video resolution

} elsif ( length( $OPTS{'i'} ) ) {                        # initialize (print an empty rc file)
   print "$ENV{'HOME'}/.vtprc created.\n";
}

### PREFIX

# here we set the prefix in environment mode (being run by the windows manager typically)
# and from the cli if requested.

if ( defined( $OPTS{'e'} ) ) {

   open( VTPENTRY, "vtp-entry.pl -d video -m \'file prefix\' |" ) || die("unable to run vtp-entry check your path");
   $OPTS{'p'} = <VTPENTRY>;
   close(VTPENTRY);
}

if ( defined( $OPTS{'f'} ) ) {
   $rctemplate->append( 'vtp_videogeom' => '' );
}

if ( length( $OPTS{'p'} ) ) {
   $rctemplate->append( 'vtp_videoprefix' => $OPTS{'p'} );
   $rctemplate->append( 'vtp_audioprefix' => $OPTS{'p'} );
   $rctemplate->append( 'vtp_imageprefix' => $OPTS{'p'} );
}

# add the pids if offered.

&printrc($rctemplate);

sub printrc {    #
   my $rctemplate = shift;

   # From Pdt::SourceEnv, this function normalizes quotes
   # to single quotes for the specified fields. This corrects
   # for bash not including the quotes in rendering.

   singlequote( $rctemplate, 'vtp_videogeom', 'vtp_imagegeom' );

   open( VTP, ">$vtpfile" );

   print VTP $rctemplate->output();

   close(VTP);
}

sub dohelp {
   print "help unimplemented\n";
   exit;
}

