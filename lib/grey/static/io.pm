use v5.42;
use experimental qw(builtin);
use builtin qw(load_module);

package grey::static::io;

our $VERSION = '0.01';

use File::Basename ();

sub import {
    my ($class, @subfeatures) = @_;

    # If no subfeatures specified, do nothing
    return unless @subfeatures;

    # Load each subfeature
    for my $subfeature (@subfeatures) {
        if ($subfeature eq 'stream') {
            # Add the stream directory to @INC
            use lib File::Basename::dirname(__FILE__) . '/io/stream';

            # Load the IO::Stream classes
            load_module('IO::Stream::Files');
            load_module('IO::Stream::Directories');
        }
        else {
            die "Unknown io subfeature: $subfeature";
        }
    }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

grey::static::io - IO utilities and streams

=head1 SYNOPSIS

    use grey::static qw[ functional stream io::stream ];

    # Read file as stream of lines
    my @lines = IO::Stream::Files
        ->lines('/path/to/file.txt')
        ->collect(Stream::Collectors->ToList);

    # Read file as stream of bytes
    my @bytes = IO::Stream::Files
        ->bytes('/path/to/file.bin')
        ->collect(Stream::Collectors->ToList);

    # Stream files from a directory
    my @txt_files = IO::Stream::Directories
        ->files('/path/to/dir')
        ->grep(sub ($path) { $path =~ /\.txt$/ })
        ->collect(Stream::Collectors->ToList);

    # Recursively walk directory tree
    my @all_files = IO::Stream::Directories
        ->walk('/path/to/dir')
        ->collect(Stream::Collectors->ToList);

=head1 DESCRIPTION

The C<io> feature provides IO utilities organized as sub-features. Currently
only the C<io::stream> sub-feature is available, which provides stream-based
file and directory operations.

=head1 SUB-FEATURES

=head2 io::stream

Provides C<IO::Stream::Files> and C<IO::Stream::Directories> classes for
stream-based file and directory operations. Requires the C<stream> feature.

=head1 CLASSES

=head2 IO::Stream::Files

Factory class for creating file-based streams.

=head3 Class Methods

=over 4

=item C<< lines($fh, %opts) >>

Creates a stream of lines from a file handle, file path, or Path::Tiny object.

B<Parameters:>

=over 4

=item C<$fh>

A file handle (GLOB or IO::Handle), file path string, or Path::Tiny object.
If a string is provided, the file is opened in read mode.

=item C<%opts>

Optional parameters passed to the underlying source.

=back

B<Returns:> A C<Stream> where each element is a line from the file (including
the newline character).

=item C<< bytes($fh, %opts) >>

Creates a stream of bytes from a file handle, file path, or Path::Tiny object.

B<Parameters:>

=over 4

=item C<$fh>

A file handle (GLOB or IO::Handle), file path string, or Path::Tiny object.
If a string is provided, the file is opened in read mode.

=item C<%opts>

Optional parameters passed to the underlying source.

=back

B<Returns:> A C<Stream> where each element is a single byte from the file.

=back

=head2 IO::Stream::Directories

Factory class for creating directory-based streams.

=head3 Class Methods

=over 4

=item C<< files($dir, %opts) >>

Creates a stream of files (and directories) in the specified directory.

B<Parameters:>

=over 4

=item C<$dir>

A directory path string or Path::Tiny object.

=item C<%opts>

Optional parameters passed to the underlying source.

=back

B<Returns:> A C<Stream> where each element is a Path::Tiny object representing
a file or subdirectory in C<$dir> (non-recursive).

=item C<< walk($dir, %opts) >>

Recursively walks the directory tree, returning all files and subdirectories.

B<Parameters:>

=over 4

=item C<$dir>

A directory path string or Path::Tiny object to start walking from.

=item C<%opts>

Optional parameters passed to the underlying source.

=back

B<Returns:> A C<Stream> where each element is a Path::Tiny object representing
a file or subdirectory anywhere in the tree under C<$dir>.

This is implemented using C<Stream>'s C<recurse> operation, expanding directories
into their contents automatically.

=back

=head1 DEPENDENCIES

The C<io::stream> sub-feature requires:

=over 4

=item *

L<Path::Tiny> - For path manipulation

=item *

The C<stream> feature must be loaded

=item *

The C<functional> feature should be loaded for stream operations

=back

=head1 SEE ALSO

L<grey::static>, L<grey::static::stream>, L<Path::Tiny>

=head1 AUTHOR

grey::static

=cut
