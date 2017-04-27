#!/usr/bin/env perl6
use JSON::Fast;
use v6.d.PREVIEW;
use lib 'lib';
use OO::Monitors;
use license_check;
use fetch;
use ok-meta-fields;
constant $eco-meta = 'http://ecosystem-api.p6c.org/projects.json';
# Gets the distribution of tag usage and the usage of license tags
monitor mon-list {
    has @!list;
    method push ($item) {
        @!list.push: $item;
    }
    method pop {
        @!list.pop;
    }
    method set (@thing) {
        @!list = @thing;
    }
    method get {
        @!list;
    }
    method append (@*things) {
        @!list.push: $_ for @*things;
    }
}
sub get-distribution {
    my $lock = Lock.new;
    my $lock2 = Lock.new;
    my $m-list = mon-list.new;
    note "getting list";
    my ($list, $lrtrn) = fetch-url 'https://raw.githubusercontent.com/perl6/ecosystem/master/META.list';
    note "got list";
    my %json-hash;
    my @proc-prom;
    for $list.lines -> $url {
        my @args = 'curl', '-s', $url;
        my $proc = Proc::Async.new(|@args, :out);
        $proc.stdout.tap( -> $out {
            $lock.protect( {
                %json-hash{$url} ~= $out;
             } );
        });
        $*ERR.print('.');
        my $prom = $proc.start;
        $lock2.protect: { @proc-prom.push($prom) };
    }
    loop {
        if @proc-prom.elems < $list.lines.elems {
            sleep 0.5;
        }
        else {
            await Promise.allof(@proc-prom);
            last;
        }
    }
    for %json-hash.kv -> $key, $value {
        my $result = try { from-json($value) };
        $m-list.list.append($result.keys);
    }
    $*ERR.print: "\n";
    my $bag = Bag($m-list.get);
    say ($bag<license> / $bag<name>) * 100 ~ '% of all modules have license fields';
    say "{$bag<name>} modules {$bag<license>} have license metadata";
    say $bag.sort(-*.value.Int);
}
sub MAIN (Bool:D :$distribution = False) {
    if $distribution {
        get-distribution;
        exit;
    }
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
    #my @slugs;
    #for 'pull-based-on-file.txt'.IO.lines {
    #    m/^$<slug>=(\S+)/;


    #}
    my @presort = get-noncompliant :license;
    my @no-licenses = @presort.grep({ $_ ne any(@attempted)} );

    note @no-licenses.elems;
    my @locks = Lock.new xx 9;
    my $unlocks = Channel.new;
    $unlocks.send($_) for @locks;
    my $slugs = mon-list.new;
    my $no-licenses = mon-list.new;
    $no-licenses.set: @no-licenses;
    react {
        whenever $unlocks -> $unlock {
            $unlock.protect({
                $slugs.push: start {
                    CATCH { .note }
                    my $return = Nil;
                    my $name = $no-licenses.pop;
                    my $slug = get-slug $name;
                    if $slug ~~ Str:D {
                        my ($has-license) = has-license $slug;
                        if $has-license {
                            say $slug, " $has-license";
                            $return = $slug => $has-license;
                        }
                    }
                    $unlocks.send($unlock);
                    $return;
                };
            });

        }

    }
    my @slugs = $slugs.get».result.grep(*.defined);
    spurt "license-list.json", to-json(@slugs);
}
# Gets which modules have noncompliant fields in the META files
# uses ecosystem api thing which updates probably every 15 mins
sub get-noncompliant (Bool:D :$fields = False, Bool:D :$license = False) {
    my ($eco-meta-file, $rtncode) = fetch-url $eco-meta;
    my $json = from-json($eco-meta-file);
    my (%things, @no-license);
    if $license {
        for ^$json.elems -> $elem {
            unless $json[$elem]<license>:exists {
                @no-license.push: $json[$elem]<name>;
            }
        }
        note "Modules with no license fields\n";
        note @no-license.join(", ");
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
    if $slug ~~ /jonathanstowe/ {
        note "Skipping $slug due to exception";
        return False;
    }
    #GET /repos/:owner/:repo/contents/:path
    #https://api.github.com/repos/samcv/URL-Find/contents/
    #my $prefix = "https://raw.githubusercontent.com/$slug/master";
    my $prefix = "https://api.github.com/repos/$slug/contents/";
    my ($json, $rtrncode) = fetch-url $prefix, :token;
    my $json-txt = from-json($json);
    my @license-files;
    for ^$json-txt.elems {
        if $json-txt[$_]<name> ~~ /:i copying|license|licence/ {
            @license-files.push($json-txt[$_]<download_url>);
        }
    }
    note @license-files;
    if @license-files.elems == 1 {
        my ($txt, $rtrncode) = fetch-url @license-files[0];
        return compare-them($txt);
    }
    return False;
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
