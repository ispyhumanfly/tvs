#!/usr/bin/perl
# $Id: index.pl, v0.0.2 06/23/2007 12:05:00 dan stephenson ( ispyhumanfly ) Exp$
#
#   revision info: see the changelog for additional info...

use CGI::Carp qw/ warningsToBrowser fatalsToBrowser /;
use warnings;
use strict;

# required nuport modules...
use lib 'library/';
use controller;

# subroutine to initialize nuport...
sub start_nuport {

    # initiate the Controller class and begin instance handling...
    my $ctrl = new Controller;
    $ctrl->process();

    # all done! =]
    exit(0);

}

# set program start point...
start_nuport();
