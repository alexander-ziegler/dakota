{
    # include  ?dquote-str ;
    # =>
    # #include ?dquote-str
    'include-stmt' => {
        'dependencies' => [],
        'lhs' => [      'include', '?dquote-str', ';' ],
        'rhs' => [ '#', 'include', '?dquote-str'      ]
    },

    # how about include <...> ;

    # klass     ?ident ;
    # =>
    # namespace ?ident {}
    'klass-decl' => {
        'dependencies' => [],
	'lhs' => [ 'klass',     '?ident', ';'      ],
	'rhs' => [ 'namespace', '?ident', '{', '}' ]
    },

    # klass     ?ident {
    # =>
    # namespace ?ident {
    'klass-defn' => {
        'dependencies' => [],
	'lhs' => [ 'klass',     '?ident', '{' ],
	'rhs' => [ 'namespace', '?ident', '{' ]
    },

    # superklass ?ident ;
    # =>
    # 
    'superklass-decl' => {
        'dependencies' => [],
        'lhs' => [ 'superklass', '?ident', ';' ],
        'rhs' => []
     },

    # how about klass ?ident ;
    # how about trait ?list-in ;

    # slots          { ... }
    # =>
    # struct slots-t { ... } ;
    'slots-defn' => {
        'dependencies' => [],
        'lhs' => [ 'slots',             '?block'      ],
        'rhs' => [ 'struct', 'slots-t', '?block', ';' ]
    },

    # ?type => ?list-member ,|)
    # =>
    # ?type                 ,|)
    'keyword-args-defn' => {
        'dependencies' => [],
         'lhs' => [ '?type', '?ident', '=>', '?list-member', '?list-member-term' ], # we can drop the last one
         'rhs' => [ '?type', '?ident',                       '?list-member-term' ]  # we can drop the last one
    },

    # dk:     ?ka-ident ( ?list-in       )
    # =>
    # dk: va: ?ka-ident ( ?list-in, NULL )
    'keyword-args-wrap' => {
        'dependencies' => [ 'keyword-args-defn', 'super' ],
         'lhs' => [ 'dk', ':',            '?ka-ident', '(', '?list-in',              ')' ],
         'rhs' => [ 'dk', ':', 'va', ':', '?ka-ident', '(', '?list-in', ',', 'NULL', ')' ]
    },

    #       ?ident => ?list-member
    # =>
    #  $ ## ?ident ,  ?list-member
    'keyword-args-use' => {
        'dependencies' => [ 'keyword-args-defn' ],
         'lhs' => [            '?ident', '=>', '?list-member' ], # we can drop the last one
         'rhs' => [ '$', '##', '?ident', ',',  '?list-member' ]  # we can drop the last one
    },

    # method alias (...)
    # =>
    # method
    'method-alias' => {
        'dependencies' => [],
        'lhs' => [ 'method', 'alias', '?list' ],
        'rhs' => [ 'method'                   ]
    },

    #                ?visibility method ?type va : ?ident(...) { ... }
    # =>
    # namespace va { ?visibility method ?type      ?ident(...) { ... } }
    'va-method' => {
        'dependencies' => [ 'method-alias' ],
        'lhs' => [                         '?visibility', 'method', '?type', 'va', ':', '?ident', '?list', '?block'      ],
        'rhs' => [ 'namespace', 'va', '{', '?visibility', 'method', '?type',            '?ident', '?list', '?block', '}' ]
    },

    # export method ?type ?ident(...)
    # =>
    # extern        ?type ?ident(...)
    'export-method' => {
        'dependencies' => [ 'method-alias', 'va-method' ],
        'lhs' => [ 'export', 'method', '?type', '?ident', '?list' ],
        'rhs' => [ 'extern',           '?type', '?ident', '?list' ]
    },

    # method ?type ?ident(...)
    # =>
    # static ?type ?ident(...)
    'method' => {
        'dependencies' => [ 'export-method', 'method-alias', 'va-method' ],
        'lhs' => [ 'method', '?type', '?ident', '?list' ],
        'rhs' => [ 'static', '?type', '?ident', '?list' ]
    },

    # try to merge super and va-super (make the va: optional)

    # dk:?ident(super ,|)
    # =>
    # dk:?ident(super:construct(self,klass) ,|)
    'super' => {
        'dependencies' => [],
        'lhs' => [ 'dk', ':', '?ident', '(', 'super',                                                   '?list-member-term' ], # we can drop the last one
        'rhs' => [ 'dk', ':', '?ident', '(', 'super', ':', 'construct', '(', 'self', ',', 'klass', ')', '?list-member-term' ]  # we can drop the last one
    },

    # for the very rare case that a user calls the dk:va: generic
    # dk:va:?ident(super ,|)
    # =>
    # dk:va:?ident(super:construct(self,klass) ,|)
    'va-super' => {
        'dependencies' => [],
        'lhs' => [ 'dk', ':', 'va', ':', '?ident', '(', 'super',                                                   '?list-member-term' ], # we can drop the last one
        'rhs' => [ 'dk', ':', 'va', ':', '?ident', '(', 'super', ':', 'construct', '(', 'self', ',', 'klass', ')', '?list-member-term' ]  # we can drop the last one
    },

    # self.?ident
    # =>
    # unbox(self)->?ident
    'slot-access' => {
        'dependencies' => [],
        'lhs' => [               'self',      '.',  '?ident' ],
        'rhs' => [ 'unbox', '(', 'self', ')', '->', '?ident' ]
    },

    # ?ident:box({ ... })
    # =>
    # ?ident:box(?ident:construct(...))
    'box-arg-compound-literal' => {
        'dependencies' => [],
        'lhs' => [ '?ident', ':', 'box', '(',                             '{', '?block-in', '}', ')' ],
        'rhs' => [ '?ident', ':', 'box', '(', '?ident', ':', 'construct', '(', '?block-in', ')', ')' ]
    },

    # throw                        make (
    # =>
    # throw dk-current-exception = make (
    'throw-capture-exception' => {
        'dependencies' => [],
        'lhs' => [ 'throw',                              'make', '(', '?list-in', ')' ], # we can drop the last two
        'rhs' => [ 'throw', 'dk-current-exception', '=', 'make', '(', '?list-in', ')' ], # we can drop the last two
    },

    # make    (            ?ident   ,|)
    # =>
    # dk:init ( dk:alloc ( ?ident ) ,|)
    'make' => {
        'dependencies' => [ 'throw-capture-exception' ],
        'lhs' => [ 'make',                                     '(', '?list-member',      '?list-member-term' ], # we can drop the last one
        'rhs' => [ 'dk', ':', 'init', '(', 'dk', ':', 'alloc', '(', '?list-member', ')', '?list-member-term' ]  # we can drop the last one
    },

    # export enum ?type-ident { ... }
    # =>
    # 
    'export-enum' => {
        'dependencies' => [],
        'lhs' => [ 'export', 'enum', '?type-ident', '?block' ],
        'rhs' => []
    },

    # foo:slots-t* slt = unbox(bar)
    # becomes
    # foo:slots-t* slt = foo:unbox(bar)

    # foo:slots-t& slt = *unbox(bar)
    # becomes
    # foo:slots-t& slt = *foo:unbox(bar)

    # foo-t* slt = unbox(bar)
    # becomes
    # foo-t* slt = foo:unbox(bar)

    # foo-t& slt = *unbox(bar)
    # becomes
    # foo-t& slt = *foo:unbox(bar)
}
