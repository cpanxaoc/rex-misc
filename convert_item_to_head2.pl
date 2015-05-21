#!/usr/bin/perl -w

# Copyright (c) 2015 by Brian Manning <brian at xaoc dot org>

# For support with this file, please file an issue on the GitHub issue tracker
# for this project: https://github.com/cpanxaoc/rex-misc/issues

=head1 NAME

B<convert_item_to_head2.pl> - Convert C<=item> tags in POD to C<=head2> for
C<EXPORTED FUNCTIONS> and C<CLASS METHOD> blocks.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

 perl convert_item_to_head2.pl [OPTIONS]

 Script options:
 -h|--help          Shows this help text
 -d|--debug         Debug script execution
 -v|--verbose       Verbose script execution
 -c|--colorize      Always colorize script output

 Other script options:
 -p|--path          Path to code repo to convert

 Example usage:

 # list the structure of an XLS file
 convert_item_to_head2.pl --option /path/to/a/file \

You can view the full C<POD> documentation of this file by calling
C<perldoc convert_item_to_head2.pl>.

=cut

our @options = (
    # script options
    q(debug|d),
    q(verbose|v),
    q(help|h),
    q(colorize|c), # always colorize output
    # other options

    q(path|p=s),
);

=head1 DESCRIPTION

B<convert_item_to_head2.pl> - Convert C<=item> tags in POD to C<=head2> for
C<EXPORTED FUNCTIONS> and C<CLASS METHOD> blocks.

=head1 PodConvert::Config

An object used for storing configuration data.

=cut

#############################
# PodConvert::Config #
#############################
package PodConvert::Config;
use strict;
use warnings;
use Getopt::Long;
use Log::Log4perl;
use Pod::Usage;
use POSIX qw(strftime);

=head2 new( )

Creates the L<PodConvert::Config> object, and parses out options using
L<Getopt::Long>.

=cut

sub new {
    my $class = shift;

    my $self = bless ({}, $class);

    # script arguments
    my %args;

    # parse the command line arguments (if any)
    my $parser = Getopt::Long::Parser->new();

    # pass in a reference to the args hash as the first argument
    $parser->getoptions( \%args, @options );

    # assign the args hash to this object so it can be reused later on
    $self->{_args} = \%args;

    # dump and bail if we get called with --help
    if ( $self->get(q(help)) ) { pod2usage(-exitstatus => 1); }

    # return this object to the caller
    return $self;
}

=head2 get($key)

Returns the scalar value of the key passed in as C<key>, or C<undef> if the
key does not exist in the L<PodConvert::Config> object.

=cut

sub get {
    my $self = shift;
    my $key = shift;
    # turn the args reference back into a hash with a copy
    my %args = %{$self->{_args}};

    if ( exists $args{$key} ) { return $args{$key}; }
    return undef;
}

=head2 set( key => $value )

Sets in the L<PodConvert::Config> object the key/value pair passed in as
arguments.  Returns the old value if the key already existed in the
L<PodConvert::Config> object, or C<undef> otherwise.

=cut

sub set {
    my $self = shift;
    my $key = shift;
    my $value = shift;
    # turn the args reference back into a hash with a copy
    my %args = %{$self->{_args}};

    if ( exists $args{$key} ) {
        my $oldvalue = $args{$key};
        $args{$key} = $value;
        $self->{_args} = \%args;
        return $oldvalue;
    } else {
        $args{$key} = $value;
        $self->{_args} = \%args;
    }
    return undef;
}

=head2 defined($key)

Returns "true" (C<1>) if the value for the key passed in as C<key> is
C<defined>, and "false" (C<0>) if the value is undefined, or the key doesn't
exist.

=cut

sub defined {
    my $self = shift;
    my $key = shift;
    # turn the args reference back into a hash with a copy
    my %args = %{$self->{_args}};

    # Can't use Log4perl here, since it hasn't been set up yet
    if ( exists $args{$key} ) {
        #warn qq(exists: $key\n);
        if ( defined $args{$key} ) {
            #warn qq(defined: $key; ) . $args{$key} . qq(\n);
            return 1;
        }
    }
    return 0;
}

=head2 get_args( )

Returns a hash containing the parsed script arguments.

=cut

sub get_args {
    my $self = shift;
    # hash-ify the return arguments
    return %{$self->{_args}};
}

################
# package main #
################
package main;

# Core modules
use 5.010;
use utf8;
use Carp;

### External modules
use strictures 2;
use File::Find::Rule;
use Log::Log4perl qw(get_logger :no_extra_logdie_message);
use Log::Log4perl::Level;

    binmode(STDOUT, ":utf8");
    # create a config object
    my $cfg = PodConvert::Config->new();

    # Start setting up the Log::Log4perl object
    my $log4perl_conf = qq(log4perl.rootLogger = WARN, Screen\n);
    if ( $cfg->defined(q(verbose)) && $cfg->defined(q(debug)) ) {
        die(q(Script called with --debug and --verbose; choose one!));
    } elsif ( $cfg->defined(q(debug)) ) {
        $log4perl_conf = qq(log4perl.rootLogger = DEBUG, Screen\n);
    } elsif ( $cfg->defined(q(verbose)) ) {
        $log4perl_conf = qq(log4perl.rootLogger = INFO, Screen\n);
    }

    # Use color when outputting directly to a terminal, or when --colorize was
    # used
    if ( -t STDOUT || $cfg->get(q(colorize)) ) {
        $log4perl_conf .= q(log4perl.appender.Screen )
            . qq(= Log::Log4perl::Appender::ScreenColoredLevels\n);
    } else {
        $log4perl_conf .= q(log4perl.appender.Screen )
            . qq(= Log::Log4perl::Appender::Screen\n);
    }

    $log4perl_conf .= qq(log4perl.appender.Screen.stderr = 1\n)
        . qq(log4perl.appender.Screen.utf8 = 1\n)
        . qq(log4perl.appender.Screen.layout = PatternLayout\n)
        . q(log4perl.appender.Screen.layout.ConversionPattern )
        # %r: number of milliseconds elapsed since program start
        # %p{1}: first letter of event priority
        # %4L: line number where log statement was used, four numbers wide
        # %M{1}: Name of the method name where logging request was issued
        # %m: message
        # %n: newline
        . qq|= [%8r] %p{1} %4L (%M{1}) %m%n\n|;
        #. qq( = %d %p %m%n\n)
        #. qq(= %d{HH.mm.ss} %p -> %m%n\n);

    # create a logger object, and prime the logfile for this session
    Log::Log4perl::init( \$log4perl_conf );
    my $log = get_logger("");

    $log->logdie(qq(Missing '--path' argument))
        unless ( $cfg->defined(q(path)) );
    $log->logdie(qq(Path ) . $cfg->get(q(path)) . q( doesn't exist))
        unless ( -d $cfg->get(q(path)) );

    # print a nice banner
    $log->info(qq(Starting convert_item_to_head2.pl, version $VERSION));
    $log->info(qq(My PID is $$));

    ### MAIN SCRIPT
    my $mod_path = $cfg->get(q(path));
    # replace the tilde if it exists at the beginning of the path
    if ( $mod_path =~ m!/$!) {
        $mod_path =~ s!/$!!;
        say qq(mod_path is now $mod_path);
    }
    my @modules = File::Find::Rule->file()
                                ->name(q(*.pm))
                                ->in($mod_path);

    foreach my $mod_file ( @modules ) {
        my $mod_name = $mod_file;
        $mod_name =~ s!^$mod_path/lib/!!;
        $mod_name =~ s!/!::!g;
        say qq(==== Checking module $mod_name ====);
        open(my $fh, q(<), $mod_file);
        my ($over_count, $line_count);
        foreach my $line ( <$fh> ) {
            $line_count++;
            my $pre = sprintf(q(%4d), $line_count);
            chomp($line);
            if ( $line =~ /^=head[1234]/ ) {
                say qq($pre header: $line);
            }
            if ( $line =~ /^=over/ ) {
                say qq($pre   over: $line);
                $over_count++;
            }
            if ( $line =~ /^=back/ ) {
                say qq($pre   back: $line);
                $over_count--;
                if ( $over_count < 0 ) {
                    die qq($pre ERROR: unmatched '=back' POD directive);
                }
            }
        }
    }

=head1 AUTHOR

Brian Manning, C<< <brian at xaoc dot org> >>

=head1 BUGS

Please report any bugs or feature requests to the GitHub issue tracker for
this project:

C<< <https://github.com/spicyjack/public/issues> >>.

=head1 SUPPORT

You can find documentation for this script with the perldoc command.

    perldoc convert_item_to_head2.pl

=head1 COPYRIGHT & LICENSE

Copyright (c) 2015 Brian Manning, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

# fin!
# vim: set shiftwidth=4 tabstop=4
