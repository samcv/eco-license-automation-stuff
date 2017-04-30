sub run-and-return-all (@args) is export {
    my Promise:D @list-of-procs;
    my @channels;
    for @args -> $pair {
        my Proc::Async $proc = Proc::Async.new(|$pair.value, :out);
        @channels.push: $proc.stdout.Channel;
        @list-of-procs.push: $proc.start;
    }
    await Promise.allof: @list-of-procs;
    my @results;
    for ^@args.elems {
        my $pair = @args[$_];
        @results.push: $pair.key =>
        @channels[$_].list.join;
    }
    @results;
}
