sub run-and-return-all (@args) is export {
    use OO::Monitors;
    my monitor list-thing {
        has %!hash;
        method add (Str:D $to-add, $whoami) { push %!hash{$whoami}, $to-add }
        method get ($whoami) { %!hash{$whoami}.join }
    }
    my list-thing $list = list-thing.new;
    my Promise:D @list-of-procs;
    for @args -> $pair {
        my Proc::Async $proc = Proc::Async.new(|$pair.value, :out);
        $proc.stdout.tap( -> $out {
            $list.add($out, $pair.key);
        });
        @list-of-procs.push: $proc.start;
    }
    await Promise.allof: @list-of-procs;
    my @results;
    for @args -> $pair {
        @results.push: $pair.key => $list.get($pair.key);
    }
    @results;
}
