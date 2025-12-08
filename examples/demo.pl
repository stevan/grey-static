#!/usr/bin/env perl
use v5.42;
use lib '../lib';
use grey::static qw[diagnostics];

# Simulating a typical application structure with nested calls

sub get_user_from_db {
    my ($id) = @_;
    # Simulate a database lookup that returns undef for invalid IDs
    if ($id < 0) {
        warn "Invalid user ID: $id";
        return undef;
    }
    return { name => "User $id", id => $id, email => "user$id\@example.com" };
}

sub validate_user {
    my ($user) = @_;
    # This will fail if $user is undef - calling method on undef
    return $user->get_email =~ /\@/;
}

sub process_user {
    my ($id) = @_;
    my $user = get_user_from_db($id);
    validate_user($user);
    return $user;
}

sub handle_request {
    my ($user_id) = @_;
    my $user = process_user($user_id);
    say "Processing user: $user->{name}";
}

# Main entry point - this will trigger a warning, then an error
handle_request(-1);
