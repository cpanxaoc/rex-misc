#!/usr/bin/perl -w

# Copyright (c) 2015 by Brian Manning <cpan at xaoc dot org>

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
 -p|--path          Path to code repo to convert

 Example usage:

 # list the structure of an XLS file
 convert_item_to_head2.pl --path /path/to/a/dir \

You can view the full C<POD> documentation of this file by calling
C<perldoc convert_item_to_head2.pl>.

=cut

our @options = (
    # script options
    q(help|h),
    q(path|p=s),
);

=head1 DESCRIPTION

B<convert_item_to_head2.pl> - Convert C<=item> tags in POD to C<=head2> for
C<EXPORTED FUNCTIONS> and C<CLASS METHOD> blocks.

=cut

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
use Digest::MD5 qw(md5 md5_hex md5_base64);
use File::Find::Rule;
use Getopt::Long;
use Text::Diff;

    binmode(STDOUT, ":utf8");
    # script arguments
    my %args;

    # parse the command line arguments (if any)
    my $parser = Getopt::Long::Parser->new();

    # pass in a reference to the args hash as the first argument
    $parser->getoptions( \%args, @options );

    die(qq(Missing '--path' argument))
        unless ( defined $args{path} );
    die(qq(Path ) . $args{path} . q( doesn't exist))
        unless ( -d $args{path} );

    ### MAIN SCRIPT
    my $mod_path = $args{path};
    # replace the tilde if it exists at the beginning of the path
    if ( $mod_path =~ m!/$!) {
        $mod_path =~ s!/$!!;
        #say qq(mod_path is now $mod_path);
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
        my @file_contents = <$fh>;
        close($fh);
        # concatinate all of the lines in the file together; since we still
        # have newlines in the file, everything should "Just Work"
        my $old_file = join(q(), @file_contents);
        my $over_count = 0;
        my $line_count = 0;
        my $functions_methods_flag = 0;
        my $new_file = q();
        foreach my $line ( @file_contents ) {
            $line_count++;
            my $pre = sprintf(q(%4d), $line_count);
            if ( $line =~ /^=head[1234]/ ) {
                print qq($pre    header: $line);
                if ( $line =~ /EXPORTED FUNCTIONS|METHODS/ ) {
                    $functions_methods_flag = 1;
                }
            } elsif ( $line =~ /^=over/ ) {
                $over_count++;
                if ( $over_count == 1 && $functions_methods_flag == 1 ) {
                    say qq(Deleting =over at line $line_count);
                    undef $line;
                } else {
                    print qq($pre   over($over_count): $line);
                }
            } elsif ( $line =~ /^=back/ ) {
                if ( $over_count < 0 ) {
                    die qq($pre ERROR: unmatched '=back' POD directive);
                } elsif ( $over_count == 1 && $functions_methods_flag == 1 ) {
                    say qq(Deleting =back at line $line_count);
                    $functions_methods_flag = 0;
                    undef $line;
                } else {
                    print qq($pre      back: $line);
                }
                $over_count--;
            } elsif ( $line =~ /^=item/ ) {
                if ( $over_count == 1 && $functions_methods_flag == 1 ) {
                    $line =~ s/^=item/=head2/;
                }
                print qq($pre      item: $line);
            }
            if ( defined $line ) {
                $new_file .= $line;
            }
        }
        my $old_md5 = md5_base64($old_file);
        my $new_md5 = md5_base64($new_file);
        my $diff_out = diff(\$old_file, \$new_file,
            {CONTEXT => 1, STYLE => q(Table)});
        if ( length($diff_out) > 0) {
            say qq(Old file and new file don't match, writing new file);
            say qq(old: $old_md5);
            say qq(new: $new_md5);
            say qq(diff output:);
            say $diff_out;
            open(my $fh, q(>), $mod_file);
            print $fh $new_file;
            close($fh);
        } else {
            say qq(Old file and new file match, not writing new file);
            say qq(  Checksums - old: $old_md5; new $new_md5);
        }
    }

=head1 AUTHOR

Brian Manning, C<< <cpan at xaoc dot org> >>

=head1 BUGS

Please report any bugs or feature requests to the GitHub issue tracker for
this project:

C<< <https://github.com/cpanxaoc/rex-misc/issues> >>.

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
