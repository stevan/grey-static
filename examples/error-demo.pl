#!/usr/bin/env perl
use v5.42;
use lib '../lib';
use grey::static qw[error];

# Simulating a typical application structure with nested calls

sub get_user_from_db {
    my ($id) = @_;
    # Validate input and throw structured errors
    if ($id < 0) {
        Error->throw(
            message => "Invalid user ID: $id",
            hint => "User IDs must be non-negative integers"
        );
    }
    if ($id > 1000) {
        Error->throw(
            message => "User ID out of range: $id",
            hint => "User IDs must be between 0 and 1000"
        );
    }
    return { name => "User $id", id => $id, email => "user$id\@example.com" };
}

sub validate_user {
    my ($user) = @_;
    unless (defined $user) {
        Error->throw(
            message => "Cannot validate undefined user",
            hint => "Check that get_user_from_db returned a valid user"
        );
    }
    unless ($user->{email} =~ /\@/) {
        Error->throw(
            message => "Invalid email format: $user->{email}",
            hint => "Email must contain an @ symbol"
        );
    }
    return 1;
}

sub process_user {
    my ($id) = @_;
    my $user = get_user_from_db($id);
    validate_user($user);
    return $user;
}

sub handle_request {
    my ($user_id) = @_;
    eval {
        my $user = process_user($user_id);
        say "Processing user: $user->{name}";
    };
    if ($@) {
        # Error objects stringify beautifully
        print $@;
    }
}

# Examples of different error scenarios

say "Example 1: Negative user ID";
say "=" x 60;
handle_request(-1);

say "\n\nExample 2: Valid user";
say "=" x 60;
handle_request(42);

say "\n\nExample 3: User ID out of range";
say "=" x 60;
handle_request(1500);
