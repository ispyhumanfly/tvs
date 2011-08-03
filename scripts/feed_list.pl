#!/usr/bin/env perl

use local::lib 'lib';

use Modern::Perl;

use lib 'library';
use Model;

my $MODEL = Model->new;

my $inbox = $MODEL->get_articles(list => 'inbox');

say $_->{title} for @{$inbox};

