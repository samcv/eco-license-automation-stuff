sub fetch-url (Str:D $url, Bool :$header-only = False, Bool :$token = False) is export {
    my @args = 'curl';
    @args.push($header-only ?? '-Is' !! '-s');
    if $token {
        @args.append: '-H', 'Authorization: token INSERTYOURTOKENHERE';
    }
    my $cmd = run(|@args, $url, :out);
    return $cmd.out.slurp, $cmd.exitcode;
}

sub is-http-ok (Str $url) is export {
    my token http-ok { 'HTTP/' <[.\d]>+ ' 200 OK' }
    fetch-url($url, :header-only) ~~ /<http-ok>/ ?? True !! False;
}
