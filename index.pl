#!/usr/bin/perl
# index.pl - TVS auto-syndicated news portal...

use CGI::Carp qw/ warningsToBrowser fatalsToBrowser /;
use warnings;
use strict;

# required TVS modules...
use lib 'library/';
use controller;

# subroutine to initialize TVS...
sub start_tvs {

    # initiate the Controller class and begin instance handling...
    my $ctrl = new Controller;
    $ctrl->process();

    # all done! =]
    exit(0);

}

# set program start point...
start_tvs();
