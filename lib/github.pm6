sub get-git-url (Str:D $slug) {
    "git\@github.com:$slug.git";
}
sub clone-slug (Str:D $slug) is export {
    my $git = get-git-url $slug;
    my $folder = $slug.subst('/', '-', :g);
    my $cmd = run 'git', 'clone', $git, $folder;
    return $folder;
}
