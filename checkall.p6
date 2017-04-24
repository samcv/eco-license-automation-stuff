#!/usr/bin/env perl6
use JSON::Fast;
use v6.d.PREVIEW;
use lib 'lib';
use fetch;
use ok-meta-fields;
constant $eco-meta = 'http://ecosystem-api.p6c.org/projects.json';
# Gets the distribution of tag usage and the usage of license tags
sub get-distribution {
    my $lock = Lock.new;
    my @list;
    note "getting list";
    my $list = fetch-url 'https://raw.githubusercontent.com/perl6/ecosystem/master/META.list';
    note "got list";
    await do for $list.lines -> $url {
       start {
           #say $url;
           my $proc = run 'curl', '-s', $url, :out;
           my Str $out = $proc.out.slurp;
           my $result;
           try {
               $result = from-json($out);
           };
           #say $result;
           $lock.protect({
               @list.append($result.keys);
               #say @list;
           }) if $proc.exitcode == 0 and $result;
           $*ERR.print: '.';
        }
    }
    $*ERR.print: "\n";
    my $bag = Bag(@list);
    say ($bag<license> / $bag<name>) * 100 ~ '% of all modules have license fields';
    say "{$bag<name>} modules {$bag<license>} have license metadata";
    say $bag.sort(-*.value.Int);
}
#get-distribution;
my $fixed = True;
my $attempt = True;
my @attempted;
for 'modechecklist.md'.IO.lines {
    my $check = ' ';
    next unless .match(/\s*'- ['.']' \s '['? $<modname>=(\S+) ']'? /);
    my $thing = ~$<modname>;
    #next unless .match(/\s*'- ['<[xX]>']'/);
    next unless .match(/\s*'- ['<[xX]>']' /) or .match(/http\S+['pull'|'issue']/);
    #next if .match(/'http'\S+['pull'|'issue']/);
    @attempted.push: $thing;
}
my @presort = get-noncompliant :license;
my @no-licenses = @presort.grep({ $_ ne any(@attempted)} );

say @no-licenses.elems;
my @slugs;
for @no-licenses -> $name {
    next if $name ~~ Str:D;
    my $slug = get-slug $name;
    say $slug and @slugs.push($slug) if has-license $slug;

}
# Gets which modules have noncompliant fields in the META files
# uses ecosystem api thing which updates probably every 15 mins
sub get-noncompliant (Bool:D :$fields = False, Bool:D :$license = False) {
    my $json = from-json(fetch-url $eco-meta);
    my (%things, @no-license);
    if $license {
        for ^$json.elems -> $elem {
            unless $json[$elem]<license>:exists {
                @no-license.push: $json[$elem]<name>;
            }
        }
        say "Modules with no license fields\n";
        say @no-license.join(", ");
    }
    if $fields {
        for ^$json.elems -> $elem {
            unless all($json[$elem].keys) eq any(@ok-meta-keys) {
                #say $json[$elem]<name>;
                for $json[$elem].keys.grep({$_ ne any(@ok-meta-keys)}) {
                    %things{$_}.push: $json[$elem]<name>;
                }
            }
        }
        say "Modules with META fields not in META spec\n";
        for %things.keys {
            say $_ ~ ": " ~ %things{$_}.join(", ") ~ "\n";
        }
    }
    return @no-license;
    #say %things.perl;
}
sub has-license (Str:D $slug) {
    my $prefix = "https://raw.githubusercontent.com/$slug/master";
    my @files = "LICENSE";
    for @files {
        return $_ if is-http-ok "$prefix/$_";
    }
    Nil;
}
sub get-slug (Str:D $modname) {
    my token not-slash { <[\S]-[/]>+ };
    my $url = "https://modules.perl6.org/dist/$modname";
    #note "Finding slug from $modname\n $url";
    if run('curl', '-Is', $url, :out).out.lines.first(/Location/) ~~ /'Location:' \s* $<url>=(\S+)/ {
        if $<url> ~~  m/ 'http' [s]? '://github.com/' $<user>=(<not-slash>) '/' $<repo>=(<not-slash>) '/'? /  {
          return "$<user>/$<repo>";
          note "Github user $<user> github repo $<repo>";
        }
        else {
          note "Couldn't detect github from $<url>";
        }
    }
    else {
        note "couldn't find github locatieon";
    }
    Nil;
}
