sub fetch-url (Str:D $url) is export {
    my $cmd = run('curl', '-s', $url, :out);
    $cmd.out.slurp;
}

sub is-http-ok (Str $url) is export {
    my token http-ok { 'HTTP/' <[.\d]>+ ' 200 OK' }
    if qqx{curl -sI '$url'} ~~ /<http-ok>/ {
        return True;
    }
    False;
}
