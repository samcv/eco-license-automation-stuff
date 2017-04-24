sub fetch-url (Str:D $url, Bool :$header-only = False) is export {
    my @args = 'curl';
    @args.push($header-only ?? '-sI' !! '-s');
    run(|@args, $url, :out).out.slurp;
}

sub is-http-ok (Str $url) is export {
    my token http-ok { 'HTTP/' <[.\d]>+ ' 200 OK' }
    fetch-url($url, :header-only) ~~ /<http-ok>/ ?? True !! False;
}
