use Concurrent::Progress;
sub run-and-return-all (@args) is export {
    my Promise:D @list-of-procs;
    my @channels;
    my $progress = Concurrent::Progress.new;
    $progress.set-target: @args.elems;
    for @args -> $pair {
        my Proc::Async $proc = Proc::Async.new(|$pair.value, :out);
        @channels.push: $proc.stdout.Channel;
        my $start-prom = $proc.start;
        $start-prom.then({ $progress.increment });
        @list-of-procs.push: $start-prom;
    }
    react {
        whenever $progress -> $status {
            print "\r" ~ "$status.value() / $status.target() ($status.percent()%)";
        }
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
