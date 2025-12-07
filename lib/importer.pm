use v5.40;
use experimental qw[ builtin ];
use builtin      qw[ export_lexically load_module ];

package importer {
    sub import ($, $from = undef, @imports) {
        return unless defined $from;
        no warnings 'shadow';
        load_module($from)
            && export_lexically( map { ("&${_}" => $from->can($_)) } @imports )
    }
}

1;
