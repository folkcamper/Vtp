#! /Skel/bin/perl
my $VERSION='2017-08-05.07-44-31.EDT';
# fvwm-entry: a simple string getter
# -d <default> (yes/no)
# -m <Message>
# -w <width>
# -f

my $ENABLEFVWM = 1;

use Getopt::Std;
use Tk;
use X11::Xlib;

my %OPTS;
getopts( 'd:m:u:q', \%OPTS );    # path ,x string request.

# Default input strings
if   ( $OPTS{'q'} ) { $OPTS{'d'} = ''                 unless $OPTS{'d'} =~ /\w+/; }
else                { $OPTS{'d'} = 'sorry, too lazy.' unless $OPTS{'d'} =~ /\w+/; }
$OPTS{'m'} = 'I need some data:' unless $OPTS{'m'} =~ /\w+/;
$OPTS{'w'} = 40 unless $OPTS{'w'} =~ /\d+/;

my $onceflag = 0;

# Figure out our geometry
my $display        = X11::Xlib->new();
my $screenwidth    = $display->DisplayWidth();
my $screenheight   = $display->DisplayHeight();
my $windowwidth    = 240;
my $windowheight   = 50;
my $offsetwidth    = ( $screenwidth - $windowwidth ) / 2;
my $offsetheight   = ( $screenheight - $windowheight ) / 2;
my $offsetgeometry = $windowwidth . 'x' . $windowheight . '+' . $offsetwidth . '+' . $offsetheight;

# Construct GUI
my $MW = MainWindow->new();    # Tk MW
$MW->geometry($offsetgeometry);
my $WindowID = $MW->id();

my $L1 = $MW->Label( -justify => 'center', -textvariable => \$OPTS{'m'} )->pack( -side => "top", -anchor => "n", -expand => '1', -fill => 'x' );
my $E1 = $MW->Entry( -textvariable => \$OPTS{'d'}, -width => $OPTS{'w'} )->pack( -side => "bottom", -anchor => "s" );

$E1->focus();
$E1->selectionFrom(0);
$E1->selectionTo( length( $OPTS{'d'} ) );

$MW->bind( '<KeyRelease-Return>' => \&doyes );
$MW->bind( '<KeyRelease-Escape>' => \&dono );

$onceflag++;
$MW->Popup();
&warp2me if ( $onceflag == 1 && $ENABLEFVWM );

MainLoop;

sub dono {
   exit;
}

sub doyes {    #
   print $OPTS{'d'};
   exit;
}

sub warp2me {
   my $warpblock = 'FvwmCommand \'WindowID ' . $WindowID . ' WarpToWindow 50 50\'';
   system($warpblock);
}

