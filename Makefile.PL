use v5.42;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME               => 'grey::static',
    AUTHOR             => 'Stevan Little <stevan@cpan.org>',
    VERSION_FROM       => 'lib/grey/static.pm',
    ABSTRACT           => 'Opinionated Perl module loader with curated features',
    LICENSE            => 'perl_5',
    MIN_PERL_VERSION   => '5.042000',

    PREREQ_PM => {
        # Core dependencies for specific features
        'Path::Tiny'      => '0.144',  # Required by io::stream
        'Time::HiRes'     => '1.9764', # Required by time::stream
        'Term::ReadKey'   => '2.38',   # Required by tty::ansi
        'B'               => 0,        # Required by mop (core module)

        # Test dependencies
        'Test::More'       => '1.302195',
        'Test::Differences' => '0.71',
    },

    TEST_REQUIRES => {
        'Test::More'       => '1.302195',
        'Test::Differences' => '0.71',
    },

    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources => {
            repository => {
                type => 'git',
                url  => 'https://github.com/stevan/grey-static.git',
                web  => 'https://github.com/stevan/grey-static',
            },
            bugtracker => {
                web => 'https://github.com/stevan/grey-static/issues',
            },
        },
        keywords => [
            'functional',
            'streams',
            'reactive',
            'diagnostics',
            'concurrency',
            'tensor',
            'ml',
        ],
        prereqs => {
            runtime => {
                requires => {
                    'perl'           => '5.042000',
                    'Path::Tiny'     => '0.144',
                    'Time::HiRes'    => '1.9764',
                    'Term::ReadKey'  => '2.38',
                    'B'              => 0,
                },
            },
            test => {
                requires => {
                    'Test::More'       => '1.302195',
                    'Test::Differences' => '0.71',
                },
            },
        },
    },

    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'grey-static-*' },
);
